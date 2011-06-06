#++
# Copyright (c) 2007-2010, Rails Dog LLC and other contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Rails Dog LLC nor the names of its
#       contributors may be used to endorse or promote products derived from this
#       software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#--
require "rails/all"

require 'state_machine'
require 'paperclip'
require 'stringex'
require 'will_paginate'
#require 'less' #TODO RAILS3: consider making this optional
require 'nested_set'
require 'acts_as_list'
require 'resource_controller'
require 'active_merchant'
require "meta_search"
require "find_by_param"

require 'spree_core/ext/active_record'
require 'spree_core/ext/hash'

require 'spree_core/delegate_belongs_to'
ActiveRecord::Base.send :include, DelegateBelongsTo

require 'spree_core/theme_support'
require 'spree_core/enumerable_constants'

require 'spree_core/spree_custom_responder'
require 'spree_core/spree_respond_with'


require 'spree_core/ssl_requirement'
require 'spree_core/preferences/model_hooks'
require 'spree_core/preferences/preference_definition'
require 'store_helpers'
require 'spree/file_utilz'
require 'spree/calculated_adjustments'
require 'spree/current_order'
require 'spree/preference_access'
require 'spree/config'
require 'spree/mail_settings'
require 'spree/mail_interceptor'
require 'redirect_legacy_product_url'
require 'middleware/seo_assist'

require 'spree_base' # added 11-3 JBD

silence_warnings do
  require 'spree_core/authorize_net_cim_hack'
end

require 'spree_core/version'

require 'spree_core/railtie'

ActiveRecord::Base.class_eval do
  include Spree::CalculatedAdjustments
  include CollectiveIdea::Acts::NestedSet
end

if defined?(ActionView)
  require 'nested_set/helper'
  ActionView::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet::Helper
  end
end

ActiveSupport.on_load(:action_view) do
  include StoreHelpers
end
