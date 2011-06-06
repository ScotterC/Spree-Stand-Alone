class OrdersController < Spree::BaseController
  before_filter :check_authorization
  
  #From Promo
  after_filter :clear_promotions
  
  respond_to :html

  helper :products


  def show
    @order = Order.find_by_number(params[:id])
  end

  def update
    @order = current_order
    if @order.update_attributes(params[:order])
      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      respond_with(@order) { |format| format.html { redirect_to cart_path } }
    else
      respond_with(@order) 
    end
  end

  # Shows the current incomplete order from the session
  def edit
    @order = current_order(true)
  end

  # Adds a new item to the order (creating a new order if none already exists)
  #
  # Parameters can be passed using the following possible parameter configurations:
  #
  # * Single variant/quantity pairing
  # +:variants => {variant_id => quantity}+
  #
  # * Multiple products at once
  # +:products => {product_id => variant_id, product_id => variant_id}, :quantity => quantity +
  # +:products => {product_id => variant_id, product_id => variant_id}}, :quantity => {variant_id => quantity, variant_id => quantity}+
  def populate
    @order = current_order(true)

    params[:products].each do |product_id,variant_id|
      quantity = params[:quantity].to_i if !params[:quantity].is_a?(Hash)
      quantity = params[:quantity][variant_id].to_i if params[:quantity].is_a?(Hash)
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:products]

    params[:variants].each do |variant_id, quantity|
      quantity = quantity.to_i
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:variants]

    respond_with(@order) { |format| format.html { redirect_to cart_path } }
  end

  def empty
    if @order = current_order
      @order.line_items.destroy_all
    end
    
    respond_with(@order) { |format| format.html { redirect_to cart_path } }
  end

  def accurate_title
    @order && @order.completed? ? "#{Order.human_name} #{@order.number}" : I18n.t(:shopping_cart)
  end
  
  private

  def clear_promotions
    current_order.promotion_credits.destroy_all if current_order
  end

  def check_authorization
    debugger
    session[:access_token] ||= params[:token]
    order = current_order || Order.find_by_number(params[:id])

    if order
      authorize! :edit, order, session[:access_token]
    else
      authorize! :create, Order
    end
  end
  
end
