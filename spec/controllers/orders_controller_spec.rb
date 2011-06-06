require File.dirname(__FILE__) + '/../spec_helper'

describe OrdersController do

  # let(:order) { mock_model(Order, :number => "R123", :reload => nil, :save! => true) }
  # before do
  #   Order.stub(:find).with(1).and_return(order) 
  #   #ensure no respond_overrides are in effect
  #   Spree::BaseController.spree_responders[:OrdersController].clear
  # end

  context "#populate" do
    # before { Order.stub(:new).and_return(order) }
    # 
    # it "should create a new order when none specified" do
    #   Order.should_receive(:new).and_return order
    #   post :populate, {}, {}
    #   session[:order_id].should == order.id
    # end
    # 
    # context "with Variant" do
    #   before do
    #     @variant = mock_model(Variant)
    #     Variant.should_receive(:find).and_return @variant
    #   end
    # 
    #   it "should handle single variant/quantity pair" do
    #     order.should_receive(:add_variant).with(@variant, 2)
    #     post :populate, {:order_id => 1, :variants => {@variant.id => 2}}
    #   end
    #   it "should handle multiple variant/quantity pairs with shared quantity" do
    #     @variant.stub(:product_id).and_return(10)
    #     order.should_receive(:add_variant).with(@variant, 1)
    #     post :populate, {:order_id => 1, :products => {@variant.product_id => @variant.id}, :quantity => 1}
    #   end
    #   it "should handle multiple variant/quantity pairs with specific quantity" do
    #     @variant.stub(:product_id).and_return(10)
    #     order.should_receive(:add_variant).with(@variant, 3)
    #     post :populate, {:order_id => 1, :products => {@variant.product_id => @variant.id}, :quantity => {@variant.id => 3}}
    #   end
    # end
  end

  context "#update" do
    before {
      order.stub(:update_attributes).and_return true
      order.stub(:line_items).and_return([])
      order.stub(:line_items=).with([])
      Order.stub(:find_by_id).and_return(order)
    }
    # it "should not result in a flash notice" do
    #   put :update, {}, {:order_id => 1}
    #   flash[:notice].should be_nil
    # end
    # it "should render the edit view (on failure)" do
    #   order.stub(:update_attributes).and_return false
    #   order.stub(:errors).and_return({:number => "has some error"})
    #   put :update, {}, {:order_id => 1}
    #   response.should render_template :edit
    # end
    # it "should redirect to cart path (on success)" do
    #   order.stub(:update_attributes).and_return true
    #   put :update, {}, {:order_id => 1}
    #   response.should redirect_to(cart_path)
    # end
  end

  context "#empty" do
    # it "should destroy line items in the current order" do
    #   controller.stub!(:current_order).and_return(order)
    #   order.stub(:line_items).and_return([])
    #   order.line_items.should_receive(:destroy_all)
    #   put :empty
    # end
    pending "should redirect back to cart" do
      response.should redirect_to(cart_path)
      put :empty
    end
  end
  ORDER_TOKEN = "ORDER_TOKEN"

  let(:user) { mock_model User, :has_role? => false, :email => "user@example.com", :anonymous? => false }
  let(:guest_user) { mock_model User, :has_role? => false, :email => "user@example.com", :anonymous? => false }
  let(:order) { Order.new }

  # it "should understand order routes with token" do
  #   assert_routing("/orders/R123456/token/ABCDEF", {:controller => "orders", :action => "show", :id => "R123456", :token => "ABCDEF"})
  #   token_order_path("R123456", "ABCDEF").should == "/orders/R123456/token/ABCDEF"
  # end

  before do
    controller.stub :current_user => nil
    User.stub :anonymous! => guest_user
  end

  context "when no order exists in the session" do
    before { Order.stub :new => order }

    context "#populate" do

      context "when not logged in" do
        it "should create an anonymous user" do
          User.should_receive :anonymous!
          post :populate
        end
      end

      context "when authenticated as a registered user" do
        before { controller.stub :current_user => user }

        it "should not create an anonymous user" do
          User.should_not_receive :anonymous!
          post :populate
          session[:access_token].should be_nil
        end

        it "should associate the new order with the registered user" do
          post :populate
          order.user.should == user
        end
      end

      context "when not authenticated" do
        it "should create an anonymous user" do
          User.should_receive(:anonymous!).and_return guest_user
          post :populate
        end

        it "should associate the new order with the anonymous user" do
          post :populate
          order.user.should == guest_user
        end

        context "when there is an order token" do
          before { order.stub :token => ORDER_TOKEN }

          it "should store the token in the session" do
            post :populate
            session[:access_token].should == ORDER_TOKEN
          end

          it "should repalce any previous access tokens" do
            session[:access_token] = "OLD_TOKEN"
            post :populate
            session[:access_token].should == ORDER_TOKEN
          end

        end

      end

    end
  end

  context "when an order exists in the session" do
    let(:token) { "some_token" }

    before do
      controller.stub :current_order => order
      controller.stub :current_user => user
    end

    context "#populate" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :populate, :token => token
      end
    end

    context "#edit" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        get :edit, :token => token
      end
    end

    context "#update" do
      it "should check if user is authorized for :edit" do
        order.stub :update_attributes
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :update, :token => token
      end
    end

    context "#empty" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :empty, :token => token
      end
    end

  end

  context "when no authenticated user" do
    let(:order) { mock_model(Order, :user => user).as_null_object }

    context "#show" do
      before { Order.stub :find_by_number => order }

      context "when token parameter present" do
        it "should store as guest_token in session" do
          get :show, {:id => "R123", :token => "ABC"}
          session[:access_token].should == "ABC"
        end
      end

      context "when no token present" do
        it "should not store a guest_token in the session" do
          get :show, {:id => "R123"}
          session[:access_token].should be_nil
        end

        it "should redirect to login_path" do
          get :show, {:id => "R123"}
          response.should redirect_to login_path
        end
      end
    end
  end

  #TODO - move some of the assigns tests based on session, etc. into a shared example group once new block syntax released
end
