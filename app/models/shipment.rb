require 'ostruct'
class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
  belongs_to :address
  has_many :state_events, :as => :stateful
  has_many :inventory_units
  has_one :adjustment, :as => :source

  before_create :generate_shipment_number
  after_destroy :release_inventory_units
  after_save :ensure_correct_adjustment, :update_order

  attr_accessor :special_instructions
  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :inventory_units

  validates :inventory_units, :presence => true, :if => :require_inventory
  validates :shipping_method, :presence => true

  make_permalink :field => :number

  scope :shipped, where(:state => 'shipped')
  scope :ready, where(:state => 'ready')
  scope :pending, where(:state => 'pending')

  def to_param
    self.number if self.number
    generate_shipment_number unless self.number
    self.number.parameterize.to_s.upcase
  end

  def shipped=(value)
    return unless value == "1" && shipped_at.nil?
    self.shipped_at = Time.now
  end

  # The adjustment amount associated with this shipment (if any.)  Returns only the first adjustment to match
  # the shipment but there should never really be more than one.
  def cost
    adjustment ? adjustment.amount : 0
  end

  # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'pending', :use_transactions => false do
    event :ready do
      transition :from => 'pending', :to => 'ready'
    end
    event :pend do
      transition :from => 'ready', :to => 'pending'
    end
    event :ship do
      transition :from => 'ready', :to => 'shipped'
    end

    after_transition :to => 'shipped', :do => :after_ship
  end

  def editable_by?(user)
    !shipped?
  end

  def manifest
    inventory_units.group_by(&:variant).map do |i|
      OpenStruct.new(:variant => i.first, :quantity => i.last.length)
    end
  end


  def line_items
    if order.complete? and Spree::Config[:track_inventory_levels]
      order.line_items.select {|li| inventory_units.map(&:variant_id).include?(li.variant_id)}
    else
      order.line_items
    end
  end

  # Updates various aspects of the Shipment while bypassing any callbacks.  Note that this method takes an explicit reference to the
  # Order object.  This is necessary because the association actually has a stale (and unsaved) copy of the Order and so it will not
  # yield the correct results.
  def update!(order)
    old_state = self.state
    new_state = determine_state(order)
    update_attribute_without_callbacks "state", determine_state(order)
    after_ship if new_state == 'shipped' and old_state != 'shipped'
  end
  
  #from api
  def self.find_by_param(param)
    if param.to_i > 0
       Shipment.find(param)
     else
       Shipment.where(:number => param).first
     end
  end

  private

  def generate_shipment_number
    return self.number unless self.number.blank?
    record = true
    while record
      random = "H" + Array.new(11){rand(9)}.join
      record = Shipment.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end

  def description_for_shipping_charge
    "#{I18n.t(:shipping)} (#{shipping_method.name})"
  end

  # def transition_order
  #   update_attribute(:shipped_at, Time.now)
  #   # transition order to shipped if all shipments have been shipped
  #   order.ship! if order.shipments.all?(&:shipped?)
  # end

  def validate_shipping_method
    unless shipping_method.nil?
      errors.add :shipping_method, I18n.t("is_not_available_to_shipment_address") unless shipping_method.zone.include?(address)
    end
  end

  def release_inventory_units
    inventory_units.each {|unit| unit.update_attribute(:shipment_id, nil)}
  end

  # Determines the appropriate +state+ according to the following logic:
  #
  # pending    unless +order.payment_state+ is +paid+
  # shipped    if already shipped (ie. does not change the state)
  # ready      all other cases
  def determine_state(order)
    return "pending" if self.inventory_units.any? {|unit| unit.backordered?}
    return "shipped" if state == "shipped"
    order.payment_state == "balance_due" ? "pending" : "ready"
  end

  # Determines whether or not inventory units should be associated with the shipment.  This is always +false+ when
  # +Spree::Config[:track_inventory_levels]+ is set to +false.+  Otherwise its +true+ whenever the order is completed
  # (and not canceled.)
  def require_inventory
    return false unless Spree::Config[:track_inventory_levels]
    order.completed? && !order.canceled?
  end

  def after_ship
    inventory_units.each &:ship!
    ShipmentMailer.shipped_email(self).deliver
  end

  def ensure_correct_adjustment
    if adjustment
      adjustment.originator = shipping_method
      adjustment.save
    else
      shipping_method.create_adjustment(I18n.t(:shipping), order, self, true)
      reload #ensure adjustment is present on later saves
    end
  end

  def update_order
    order.update!
  end
end
