require File.dirname(__FILE__) + '/../spec_helper'

describe Payment do

  context 'validation' do
    it { should have_valid_factory(:payment) }
  end

  let(:order) { mock_model(Order, :update! => nil, :payments => []) }
  let(:gateway) { Gateway::Bogus.new(:environment => 'test', :active => true) }
  let(:card) { Factory(:creditcard) }

  before(:each) do
    @payment = Payment.new(:order => order)
    @payment.source = mock_model(Creditcard, :save => true, :payment_gateway => nil, :process => nil, :credit => nil)
    @payment.stub!(:valid?).and_return(true)
    @payment.stub!(:check_payments).and_return(nil)

    order.payments.stub!(:reload).and_return([@payment])
  end

  context "#process!" do

    context "when state is checkout" do
      before(:each) do
        @payment.source.stub!(:process!).and_return(nil)
      end
      it "should process the source" do
        @payment.source.should_receive(:process!)
        @payment.process!
      end
      it "should make the state 'processing'" do
        @payment.process!
        @payment.should be_processing
      end
    end

    context "when already processing" do
      before(:each) { @payment.state = 'processing' }
      it "should return nil without trying to process the source" do
        @payment.source.should_not_receive(:process!)
        @payment.process!.should == nil
      end
    end

  end

  context "#credit_allowed" do
    it "is the difference between offsets total and payment amount" do
      @payment.amount = 100
      @payment.stub(:offsets_total).and_return(0)
      @payment.credit_allowed.should == 100
      @payment.stub(:offsets_total).and_return(80)
      @payment.credit_allowed.should == 20
    end
  end

  context "#can_credit?" do
    it "is true if credit_allowed > 0" do
      @payment.stub(:credit_allowed).and_return(100)
      @payment.can_credit?.should be_true
    end
    it "is false if credit_allowed is 0" do
      @payment.stub(:credit_allowed).and_return(0)
      @payment.can_credit?.should be_false
    end
  end

  context "#credit" do
    context "when amount <= credit_allowed" do
      it "makes the state processing" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.credit(10)
        @payment.should be_processing
      end
      it "calls credit on the source with the payment and amount" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.source.should_receive(:credit).with(@payment, 10)
        @payment.credit(10)
      end
    end
    context "when amount > credit_allowed" do
      it "should not call credit on the source" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.credit(20)
        @payment.should be_completed
      end
    end
  end

  context "#save" do
    it "should call order#update!" do
      payment = Payment.create(:amount => 100, :order => order)
      order.should_receive(:update!)
      payment.save
    end

    context "when profiles are supported" do
      before { gateway.stub :payment_profiles_supported? => true }

      it "should create a payment profile" do
        gateway.should_receive :create_profile
        payment = Payment.create(:amount => 100, :order => order, :source => card, :payment_method => gateway)
      end
    end

    context "when profiles are not supported" do
      before { gateway.stub :payment_profiles_supported? => false }

      it "should not create a payment profile" do
        gateway.should_not_receive :create_profile
        payment = Payment.create(:amount => 100, :order => order, :source => card, :payment_method => gateway)
      end
    end
  end

end
