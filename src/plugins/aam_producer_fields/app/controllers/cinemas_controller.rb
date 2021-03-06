class CinemasController < ApplicationController
  unloadable

  layout 'admin'

  helper :sort
  include SortHelper

  before_filter :find_cinema, :only => [:edit, :update, :destroy]
	before_filter :require_admin

  def index
    sort_init ['name', 'city', 'ip_address']
    sort_update %w(ip_address city name)
    @cinema_pages, @cinemas = paginate Cinema.unscoped.order(sort_clause), :per_page => 25
  end

  def new
    @cinema = Cinema.new
  end

  def get_screens
    screens = Cinema.find_by_id(params[:id]).screens
    render json: screens
  end

  def get_devices
    devices = Cinema.find_by_id(params[:id]).devices.select('devices.id as id, category').order('category')
    devices.each do |device|
      device.category = t(device.category) # Translate to local language.
    end

    render json: devices
  end
  
  def edit
  end

  def create
    @cinema = Cinema.new(params[:cinema])

    if request.post? && @cinema.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to cinemas_path
    else
      @cinemas = Cinema.all
      render :action => 'new'
    end
  end


  def update
    if request.put? and @cinema.update_attributes(params[:cinema])
      flash[:notice] = l(:notice_successful_update)
      redirect_to cinemas_path
    else
      render :action => 'edit'
    end
  end

  def destroy
    @cinema.destroy
    redirect_to cinemas_path
  rescue
    flash[:error] =  l(:error_can_not_remove_cinema)
    redirect_to cinemas_path
  end
  
  private

  def cinemas_destroy_confirmation_message
    message = l(:text_cinemas_destroy_confirmation)
    message
  end
  
  def find_cinema
    @cinema = Cinema.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
