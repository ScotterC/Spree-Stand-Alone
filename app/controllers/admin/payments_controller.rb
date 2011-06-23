class Admin::PaymentsController < Admin::BaseController
  before_filter :load_order, :only => [:create, :new, :index, :fire]
  before_filter :load_payment, :except => [:create, :new, :index]
  before_filter :load_data

  respond_to :html

  def index
    @payments = @order.payments

    respond_with(@payments)
  end

  def new
    @payment = @order.payments.build
    respond_with(@payment)
  end

  def create
    @payment = @order.payments.build(object_params)
    if @payment.payment_method.is_a?(Gateway) && @payment.payment_method.payment_profiles_supported? && params[:card].present? and params[:card] != 'new'
      @payment.source = Creditcard.find_by_id(params[:card])
    end

    begin
      unless @payment.save
        respond_with(@payment) { |format| format.html { redirect_to admin_order_payments_path(@order) } }
        return
      end

      if @order.completed?
        @payment.process!
        flash[:notice] = flash_message_for(@payment, :successfully_created)

        respond_with(@payment) { |format| format.html { redirect_to admin_order_payments_path(@order) } }
      else
        #This is the first payment (admin created order)
        until @order.completed?
          @order.next!
        end
        flash.notice = t('new_order_completed')
        respond_with(@payment) { |format| format.html { redirect_to admin_order_url(@order) } }
      end

    rescue Spree::GatewayError => e
      flash[:error] = "#{e.message}"
      
      respond_with(@payment) { |format| format.html { redirect_to new_admin_payment_path(@order) } }
    end
  end

  def fire
    # TODO: consider finer-grained control for this type of action (right now anyone in admin role can perform)
    return unless event = params[:e] and @payment.payment_source
    if @payment.payment_source.send("#{event}", @payment)
      flash.notice = t('payment_updated')
    else
      flash[:error] = t('cannot_perform_operation')
    end
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    respond_with(@payment) { |format| format.html { redirect_to admin_order_payments_path(@order) } }
  end

  private

  def object_params
    if params[:payment] and params[:payment_source] and source_params = params.delete(:payment_source)[params[:payment][:payment_method_id]]
      params[:payment][:source_attributes] = source_params
    end
    params[:payment]
  end

  def load_data
    @amount = params[:amount] || load_order.total
    @payment_methods = PaymentMethod.available(:back_end)
    if @payment and @payment.payment_method
      @payment_method = @payment.payment_method
    else
      @payment_method = @payment_methods.first
    end
    @previous_cards = @order.creditcards.with_payment_profile
  end

  def load_order
    @order ||= Order.find_by_number! params[:order_id]
  end

  def load_payment
    @payment ||= Payment.find params[:id]
  end

end
