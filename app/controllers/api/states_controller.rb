class Api::StatesController < Api::BaseController
  before_filter :access_denied, :except => [:index, :show]

  private
  def parent
    @parent ||= Country.find(params[:country_id])
  end
end
