class Ckeditor::PicturesController < Ckeditor::ApplicationController

	###
	#
	# This overwrites the CKeditor engine pictures controller.  Images are now scoped to the user that uploaded them.
	#
	###

	respond_to :html

	def index
		@pictures = Ckeditor.picture_adapter.find_all(ckeditor_pictures_scope(assetable_id: ckeditor_current_user._id))
		@pictures = Ckeditor::Paginatable.new(@pictures).page(params[:page])
		respond_with(@pictures, :layout => @pictures.first_page?)
	end

	def create
		@picture = Ckeditor.picture_model.new
		respond_with_asset(@picture)
	end

	def destroy
		@picture.destroy
		respond_with(@picture, :location => pictures_path)
	end

	protected

	def find_asset
		@picture = Ckeditor.picture_adapter.get!(params[:id])
	end

	def authorize_resource
		model = (@picture || Ckeditor.picture_model)
		@authorization_adapter.try(:authorize, params[:action], model)
	end

end