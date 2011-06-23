class Admin::TaxonsController < Admin::BaseController
  include Railslove::Plugins::FindByParam::SingletonMethods

  respond_to :html, :json, :js

  def create
    @taxonomy = Taxonomy.find(params[:taxonomy_id])
    @taxon = @taxonomy.taxons.build(params[:taxon])
    if @taxon.save
      respond_with(@taxon) do |format|
        format.json {render :json => @taxon.to_json }
      end
    else
      flash[:error] = I18n.t('errors.messages.could_not_create_taxon')
      respond_with(@taxon) do |format|
        format.html { redirect_to @taxonomy ? edit_admin_taxonomy_url(@taxonomy) : admin_taxonomies_url }
      end
    end
  end

  def update
    update_before
    update_after
    respond_with(@taxon) do |format|
      format.html { redirect_to edit_admin_taxonomy_url(@taxonomy) }
      format.json { render :json => @taxon.to_json }
    end
  end

  def edit
    @taxonomy = Taxonomy.find(params[:taxonomy_id])
    @taxon = @taxonomy.taxons.find(params[:id])
    @permalink_part = @taxon.permalink.split("/").last

    respond_with(:admin, @taxon) 
  end

  def update
    @taxonomy = Taxonomy.find(params[:taxonomy_id])
    @taxon = @taxonomy.taxons.find(params[:id])
    parent_id = params[:taxon][:parent_id]
    new_position = params[:taxon][:position]

    if parent_id || new_position #taxon is being moved
      new_parent = parent_id.nil? ? @taxon.parent : Taxon.find(parent_id.to_i)
      new_position = new_position.nil? ? -1 : new_position.to_i

      # Bellow is a very complicated way of finding where in nested set we
      # should actually move the taxon to achieve sane results,
      # JS is giving us the desired position, which was awesome for previous setup,
      # but now it's quite complicated to find where we should put it as we have
      # to differenciate between moving to the same branch, up down and into
      # first position.
      new_siblings = new_parent.children
      if new_position <= 0 && new_siblings.empty?
        @taxon.move_to_child_of(new_parent)
      elsif new_parent.id != @taxon.parent_id
        if new_position == 0
          @taxon.move_to_left_of(new_siblings.first)
        else
          @taxon.move_to_right_of(new_siblings[new_position-1])
        end
      elsif new_position < new_siblings.index(@taxon)
        @taxon.move_to_left_of(new_siblings[new_position]) # we move up
      else
        @taxon.move_to_right_of(new_siblings[new_position]) # we move down
      end
      # Reset legacy position, if any extensions still rely on it
      new_parent.children.reload.each{|t| t.update_attribute(:position, t.position)}
      
      if parent_id
        @taxon.reload
        @taxon.set_permalink
        @taxon.save!
        @update_children = true
      end
    end

    if params.key? "permalink_part"
      parent_permalink = @taxon.permalink.split("/")[0...-1].join("/")
      parent_permalink += "/" unless parent_permalink.blank?
      params[:taxon][:permalink] = parent_permalink + params[:permalink_part]
    end
    #check if we need to rename child taxons if parent name or permalink changes
    @update_children = true if params[:taxon][:name] != @taxon.name || params[:taxon][:permalink] != @taxon.permalink

    if @taxon.update_attributes(params[:taxon])
      flash[:notice] = flash_message_for(@taxon, :successfully_updated)
    end

    #rename child taxons
    if @update_children
      @taxon.descendants.each do |taxon|
        taxon.reload
        taxon.set_permalink
        taxon.save!
      end
    end
    
    respond_with(@taxon) do |format|
      format.html {redirect_to edit_admin_taxonomy_url(@taxonomy) }
      format.json {render :json => @taxon.to_json }
    end
  end

  def destroy
    @taxon = Taxon.find(params[:id])
    @taxon.destroy
    respond_with(@taxon) { |format| format.json { render :json => '' } }
  end

  def selected
    @product = load_product
    @taxons = @product.taxons

    respond_with(:admin, @taxons)
  end

  def available
    @product = load_product
    @taxons = params[:q].blank? ? [] : Taxon.where('lower(name) LIKE ?', "%#{params[:q].mb_chars.downcase}%")
    @taxons.delete_if { |taxon| @product.taxons.include?(taxon) }

    respond_with(:admin, @taxons)
  end

  def remove
    @product = load_product
    @taxon = Taxon.find(params[:id])
    @product.taxons.delete(@taxon)
    @product.save
    @taxons = @product.taxons

    respond_with(@taxon) { |format| format.js { render_js_for_destroy } }
  end

  def select
    @product = load_product
    @taxon = Taxon.find(params[:id])
    @product.taxons << @taxon
    @product.save
    @taxons = @product.taxons

    respond_with(:admin, @taxons)
  end

  def batch_select
    @product = load_product
    @taxons = params[:taxon_ids].map{|id| Taxon.find(id)}.compact
    @product.taxons = @taxons
    @product.save
    redirect_to selected_admin_product_taxons_url(@product)
  end

  private

  def load_product
    Product.find_by_permalink! params[:product_id]
  end

end
