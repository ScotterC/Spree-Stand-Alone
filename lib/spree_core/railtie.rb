module SpreeCore
  class Engine < Rails::Engine

    config.autoload_paths += %W(#{config.root}/lib)
    # TODO - register state monitor observer?

    def self.activate

      Spree::ThemeSupport::HookListener.subclasses.each do |hook_class|
        Spree::ThemeSupport::Hook.add_listener(hook_class)
      end

      #register all payment methods (unless we're in middle of rake task since migrations cannot be run for this first time without this check)
      if File.basename( $0 ) != "rake"
        [
          Gateway::Bogus,
          Gateway::AuthorizeNet,
          Gateway::AuthorizeNetCim,
          Gateway::Eway,
          Gateway::Linkpoint,
          Gateway::PayPal,
          Gateway::SagePay,
          Gateway::Beanstream,
          Gateway::Braintree,
          PaymentMethod::Check
        ].each{|gw|
          begin
            gw.register
          rescue Exception => e
            $stderr.puts "Error registering gateway #{gw}: #{e}"
          end
        }

        #register all calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::SalesTax,
          Calculator::Vat,
          Calculator::PriceBucket
        ].each{|c_model|
          begin
            c_model.register if c_model.table_exists?
          rescue Exception => e
            $stderr.puts "Error registering calculator #{c_model}"
          end
        }

      end

      # for Promo
      if File.basename( $0 ) != "rake"
        # register promotion rules
        [Promotion::Rules::ItemTotal, Promotion::Rules::Product, Promotion::Rules::User, Promotion::Rules::FirstOrder].each &:register

        # register default promotion calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::FreeShipping
        ].each{|c_model|
          begin
            Promotion.register_calculator(c_model) if c_model.table_exists?
          rescue Exception => e
            $stderr.puts "Error registering promotion calculator #{c_model}"
          end
        }
      end

    end

    config.to_prepare &method(:activate).to_proc

    # filter sensitive information during logging
    initializer "spree.params.filter" do |app|
    app.config.filter_parameters += [:password, :password_confirmation, :number]
    
  end

  end
end
