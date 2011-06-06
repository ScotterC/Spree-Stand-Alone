require 'spree_core'
require 'devise'
require 'cancan'

require 'spree/auth/config'
require 'spree/token_resource'

module SpreeAuth


      # monkey patch until new version of devise comes out
      # https://github.com/plataformatec/devise/commit/ec5bfe9119d0e1e633629793b0de1f58f89622dc
      Devise::IndifferentHash.class_eval do
        def [](key)
          super(convert_key(key))
        end
        def to_hash; Hash.new.update(self) end
      end


    #config.to_prepare &method(:activate).to_proc
    ActiveRecord::Base.class_eval { include Spree::TokenResource }

end
