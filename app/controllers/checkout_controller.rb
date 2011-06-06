# Handles checkout logic.  This is somewhat contrary to standard REST convention since there is not actually a
# Checkout object.  There's enough distinct logic specific to checkout which has nothing to do with updating an
# order that this approach is waranted.
class CheckoutController < Spree::BaseController
  before_filter :check_authorization
  before_filter :check_registration, :except => [:registration, :update_registration]

  helper :users
  
  ssl_required

  before_filter :load_order
  rescue_from Spree::GatewayError, :with => :rescue_from_spree_gateway_error

  respond_to :html

  # Updates the order and advances to the next state (when possible.)
  def update
    if @order.update_attributes(object_params)
      if @order.next
        state_callback(:after)
      else
        flash[:error] = I18n.t(:payment_processing_failed)
        respond_with(@order, :location => checkout_state_path(@order.state)) and return
      end

      if @order.state == "complete" || @order.completed?
        flash[:notice] = I18n.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        respond_with(@order, :location => completion_route)
      else
        respond_with(@order, :location => checkout_state_path(@order.state))
      end
    else
      respond_with(@order) { |format| format.html { render :edit } }
    end
  end

  def registration
    @user = User.new
  end

  def update_registration
    # hack - temporarily change the state to something other than cart so we can validate the order email address
    current_order.state = "address"
    if current_order.update_attributes(params[:order])
      redirect_to checkout_path
    else
      @user = User.new
      render 'registration'
    end
  end


  private

  # Provides a route to redirect after order completion
  def completion_route
    order_path(@order)
  end

  def object_params
    # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
    if @order.payment?
      if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
        params[:order][:payments_attributes].first[:source_attributes] = source_params
      end
      if (params[:order][:payments_attributes])
        params[:order][:payments_attributes].first[:amount] = @order.total
      end
    end
    params[:order]
  end

  def load_order
    @order = current_order
    redirect_to cart_path and return unless @order and @order.checkout_allowed?
    redirect_to cart_path and return if @order.completed?
    @order.state = params[:state] if params[:state]
    state_callback(:before)
  end

  def state_callback(before_or_after = :before)
    method_name = :"#{before_or_after}_#{@order.state}"
    send(method_name) if respond_to?(method_name, true)
  end

  def before_address
    @order.bill_address ||= Address.default
    @order.ship_address ||= Address.default
  end

  def before_delivery
    return if params[:order].present?
    @order.shipping_method ||= (@order.rate_hash.first && @order.rate_hash.first[:shipping_method])
  end

  def before_payment
    current_order.payments.destroy_all if request.put?
  end

  def after_complete
    session[:order_id] = nil
  end

  def rescue_from_spree_gateway_error
    flash[:error] = t('spree_gateway_error_flash_for_checkout')
    render :edit
  end

  #from auth
  def check_authorization
    authorize!(:edit, current_order, session[:access_token])
  end

  # Introduces a registration step whenever the +registration_step+ preference is true.
  def check_registration
    return unless Spree::Auth::Config[:registration_step]
    return if current_user or current_order.email
    store_location
    redirect_to checkout_registration_path
  end

  # Overrides the equivalent method defined in spree_core.  This variation of the method will ensure that users
  # are redirected to the tokenized order url unless authenticated as a registered user.
  def completion_route
    return order_path(@order) if current_user
    token_order_path(@order, @order.token)
  end

end
