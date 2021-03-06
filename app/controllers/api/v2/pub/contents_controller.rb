class Api::V2::Pub::ContentsController < Api::V1::BaseController
  swagger_controller :contents, 'Contents'
  before_action :fix_0_values
  skip_before_action :attack_app_before_load, only: :widget_popular_content
  # init others content
  before_action :set_public_content, only: [:share, :stop_sharing, :prayer_reject, :prayer_accept, :add_prayers, :add_people_answer_question, :show, :likes, :stop_praying, :content_file_visit, :suggested_videos]
  
  # init my content
  before_action :set_content, except: [:create_status, :create_pray, :create_media, :create_question, :get_praying_recommended_users, :my_praying_requests, :my_praying_feeds, :my_answered_prayers, :my_praying_feeds_of_others, :prepare_live_video, :create_live_video, :trending_now, :widget_popular_content]

  def self.common_params_api(instance)
    instance.param :form, :owner_id, :integer, :optional, 'User owner of the feed (situations when someone is writing in other\'s wall, like: happy birthday Pepe)'
    instance.param :form, :privacy_level, :string, :optional, 'Privacy level for this post: public, only_me, only_friends (default public)'
    instance.param :form, :user_group_id, :integer, :optional, 'User Group ID where this content is published for'
  end
  
  swagger_api :create_status do
    summary 'Create a status feed'
    param :form, :description, :text, :required, 'Text feed content (This content supports for html tags)'
    Api::V2::Pub::ContentsController.common_params_api(self)
  end
  def create_status
    @content = current_user.contents.new(content_params('status'))
    authorize! :post, @content.user_group if @content.user_group_id
    if @content.save
      render_content
    else
      render_error_model(@content)
    end
  end


  swagger_api :suggested_videos do
    summary 'Suggested videos related to a specific video content'
    param :path, :id, :integer, :required, 'Content ID'
    param :query, :page, :integer, :optional, 'Page number of pagination'
    param :query, :per_page, :integer, :optional, 'Quantity of items per page used in pagination (default 10)'
  end
  def suggested_videos
    newsfeed_service = NewsfeedService.new(current_user, params[:page], params[:per_page])
    @contents = newsfeed_service.recent_content.where.not(id: @content.id).joins(:content_images).where(content_files: {image_content_type: ['video/mp4', 'video/x-flv', 'video/quicktime']})
    render 'api/v1/pub/contents/index'
  end

  swagger_api :update_status do
    summary 'Update an existent status feed'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :description, :text, :required, 'Text feed content (This content supports for html tags)'
    param :form, :privacy_level, :string, :optional, 'Privacy level for this post: public, only_me, only_friends, only_family (default public)'
  end
  def update_status
    authorize! :modify, @content
    if @content.update(content_params)
      render_content
    else
      render_error_model(@content)
    end
  end


  swagger_api :prepare_live_video do
    summary 'Prepare live video streaming ready to be started'
  end
  def prepare_live_video
    session = OpentokService.service.create_session :media_mode => :routed
    token = session.generate_token({role: :moderator, expire_time: Time.now.to_i+(7 * 24 * 60 * 60), data: '', initial_layout_class_list: ['focus', 'inactive'] })
    render json: {session: session.to_s, token: token, api_key: ENV['OPENTOK_KEY']}
  end
  
  swagger_api :stop_live_video do
    summary 'Stop live video streaming of current content (Note: After finished, the playback .mp4 file is not ready immediately but it is notified by FCM "content_live_video_uploaded" to content channel)'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def stop_live_video
    authorize! :modify, @content
    @content.content_live_video.try(:stop_streaming!)
    render_content
  end
  
  swagger_api :create_live_video do
    summary 'Create a new live video streaming (Once the live video is created, live streaming is auto started and other people can see the streaming...)'
    param :form, :description, :text, :required, 'Text feed content'
    param :form, :session, :text, :required, 'Live video session key (generated by "prepare live video endpoint")'
    Api::V2::Pub::ContentsController.common_params_api(self)
  end
  def create_live_video
    @content = current_user.contents.new(content_params('live_video'))
    authorize! :post, @content.user_group if @content.user_group_id
    @content.build_content_live_video(session: params[:session])
    if @content.save
      render_content
    else
      render_error_model(@content)
    end
  end

  swagger_api :update_live_video do
    summary 'Update an existent live video feed'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :description, :text, :required, 'Text feed content'
  end
  def update_live_video
    authorize! :modify, @content
    if @content.update(description: params[:description])
      render_content
    else
      render_error_model(@content)
    end
  end
  
  swagger_api :create_pray do
    summary 'Create a pray feed'
    param :form, :title, :string, :required, 'Title of the pray feed'
    param :form, :description, :text, :required, 'Description of the pray feed'
    param :form, :users_prayer_ids, :array, :optional, 'User ids requested for praying'
    Api::V2::Pub::ContentsController.common_params_api(self)
  end
  def create_pray
    @content = current_user.contents.new(content_params('pray'))
    authorize! :post, @content.user_group if @content.user_group_id
    if @content.save
      render_content
    else
      render_error_model(@content)
    end
  end

  swagger_api :update_pray do
    summary 'Update an existent pray feed'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :title, :string, :required, 'Title of the pray feed'
    param :form, :description, :text, :required, 'Description of the pray feed'
    param :form, :users_prayer_ids, :array, :optional, 'User ids requested for praying'
    param :form, :privacy_level, :string, :optional, 'Privacy level for this post: public, only_me, only_friends, only_family (default public)'
  end
  def update_pray
    authorize! :modify, @content
    if @content.update(content_params)
      render_content
    else
      render_error_model(@content)
    end
  end


  swagger_api :create_media do
    summary 'Create an media feed'
    param :form, :description, :text, :required, 'Description of the media feed'
    param :form, 'content_images_attributes[][image]', :file, :required, 'Multiple images/audios/videos to include in the feed'
    Api::V2::Pub::ContentsController.common_params_api(self)
  end
  def create_media
    @content = current_user.contents.new(content_params('image'))
    authorize! :post, @content.user_group if @content.user_group_id
    if @content.save
      render_content
    else
      render_error_model(@content)
    end
  end

  swagger_api :update_media do
    summary 'Update an existent media feed'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :description, :text, :required, 'Description of the media feed'
    param :form, 'content_images_attributes[][image]', :file, :required, 'Multiple images/audios/videos to include in the feed'
    param :form, 'content_image_ids[]', :integer, :optional, 'Array of all media ids, exclude media ids to remove them'
    param :form, :privacy_level, :string, :optional, 'Privacy level for this post: public, only_me, only_friends, only_family (default public)'
  end
  def update_media
    authorize! :modify, @content
    if @content.update(content_params)
      render_content
    else
      render_error_model(@content)
    end
  end


  swagger_api :create_question do
    summary 'Create a question feed'
    param :form, :title, :string, :required, 'Title of the question feed'
    param :form, :description, :text, :required, 'Description of the question feed'
    param :form, :user_recommended_ids, :array, :optional, 'User ids recommended to answer this question'
    Api::V2::Pub::ContentsController.common_params_api(self)
  end
  def create_question
    @content = current_user.contents.new(content_params('question'))
    authorize! :post, @content.user_group if @content.user_group_id
    if @content.save
      render_content
    else
      render_error_model(@content)
    end
  end

  swagger_api :update_question do
    summary 'Update an existent question feed'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :title, :string, :required, 'Title of the question feed'
    param :form, :description, :text, :required, 'Description of the question feed'
    param :form, :user_recommended_ids, :array, :optional, 'User ids recommended to answer this question'
    param :form, :privacy_level, :string, :optional, 'Privacy level for this post: public, only_me, only_friends, only_family (default public)'
  end
  def update_question
    authorize! :modify, @content
    if @content.update(content_params)
      render_content
    else
      render_error_model(@content)
    end
  end

  swagger_api :show do
    summary 'Return the full information of a single content'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def show
    render partial: 'api/v1/pub/contents/content', locals: {content: @content}
  end

  swagger_api :answer_pray do
    summary 'Mark current pray feed as answered'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def answer_pray
    authorize! :modify, @content
    @content.answer_pray!
    head :ok
  end

  swagger_api :answer_pray_share do
    summary 'Share testimony of answered praying feed'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def answer_pray_share
    authorize! :modify, @content
    if @content.answered_pray?
      @content.answer_pray_share!
      head :ok
    else
      render_error_messages(['The pray feed needs to be confirmed before share the testimony'])
    end
  end
  
  # pray feed custom actions
  swagger_api :add_prayers do
    summary 'Add extra prayers to a pray feed (Only owner of the feed can invite more prayers)'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :users_prayer_ids, :array, :optional, 'Array of user ids to add as prayers for current pray feed (required if phone numbers is empty)'
    param :form, :phone_numbers, :array, :optional, 'Array of phone numbers to invite as prayers for current pray feed, sample: [{number: 123123, name: "Owen"}, {number: 090909, name: "Matt"}]'
  end
  def add_prayers
    authorize! :invite_prayers, @content
    @content.add_prayers(current_user.id, params[:users_prayer_ids], params[:phone_numbers])
    head :ok
  end

  # current user can reject a praying request
  swagger_api :prayer_reject do
    summary 'Current user rejects a praying request'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def prayer_reject
    @content.content_prayers.where(user_id: current_user.id).first.try(:reject!)
    head :ok
  end

  swagger_api :prayer_accept do
    param :path, :id, :integer, :required, 'Content feed ID'
    summary 'Current user accepts a praying request of current pray feed'
  end
  def prayer_accept
    @content.content_prayers.where(user_id: current_user.id).first.try(:accept!)
    head :ok
  end

  swagger_api :stop_praying do
    param :path, :id, :integer, :required, 'Content feed ID'
    summary 'Stop praying of current user for current praying feed'
  end
  def stop_praying
    if @content.stop_praying!(current_user.id)
      render(nothing: true)
    else
      render_error_model(@content)
    end
  end

  swagger_api :get_praying_recommended_users do
    summary 'Return system recommended users to pray for a pray feed according the title and content'
    param :query, 'excluded_users[]', :array, :optional, 'Array of ID\'s of all excluded users'
    param :query, :limit, :integer, :optional, 'Indicates the quantity of items to return, default 10'
    param :form, :title, :string, :optional, 'Pray feed title'
    param :form, :content, :text, :optional, 'Pray feed description'
  end
  def get_praying_recommended_users
    users = current_user.friends.most_active.where.not(id: params[:excluded_users]).limit(params[:limit] || 10)
    render json: users.to_json({only: [:id, :full_name, :email, :avatar_url, :mention_key]})
  end

  swagger_api :my_praying_requests do
    summary 'Return all praying requests to current user'
    param :query, :page, :integer, :optional, 'Indicates number of pagination'
    param :query, :per_page, :integer, :optional, 'Indicates the quantity of items per page, default 20'
    param :query, :content_id, :integer, :optional, 'Filter the specific praying request of a content (Content ID)'
  end
  def my_praying_requests
    @contents_praying = current_user.content_prayers.no_answered.pending.page(params[:page]).per(params[:per_page] || 20)
    @contents_praying = @contents_praying.where(content_id: params[:content_id]) if params[:content_id].present?
    render :contents_praying
  end

  swagger_api :my_praying_feeds do
    summary 'Return all praying feeds created by current user (not marked as answered yet)'
    param :query, :page, :integer, :optional, 'Indicates number of pagination'
    param :query, :per_page, :integer, :optional, 'Indicates the quantity of items per page, default 20'
  end
  def my_praying_feeds
    @contents = current_user.contents.filter_prays.no_answered.page(params[:page]).per(params[:per_page] || 20).includes(:prayers, :hash_tags, :owner)
    render 'api/v1/pub/contents/index'
  end

  swagger_api :my_praying_feeds_of_others do
    summary 'Return all praying feeds accepted by current user (not marked as answered yet)'
    param :query, :page, :integer, :optional, 'Indicates number of pagination'
    param :query, :per_page, :integer, :optional, 'Indicates the quantity of items per page, default 20'
  end
  def my_praying_feeds_of_others
    @contents_praying = current_user.content_prayers.no_answered.accepted.exclude_owner.page(params[:page]).per(params[:per_page] || 20)
    render :contents_praying
  end

  swagger_api :my_answered_prayers do
    summary 'Return all praying feeds marked as answered which current user was praying for'
    param :query, :page, :integer, :optional, 'Indicates number of pagination'
    param :query, :per_page, :integer, :optional, 'Indicates the quantity of items per page, default 20'
  end
  def my_answered_prayers
    @contents_praying = current_user.content_prayers.answered.accepted.page(params[:page]).per(params[:per_page] || 20)
    render :contents_praying
  end

  # pray feed custom actions
  swagger_api :add_people_answer_question do
    summary 'Add users to answer a question feed (Only feed owner can add users)'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :form, :user_recommended_ids, :array, :required, 'Array of user ids (required if phone numbers is empty)'
    param :form, :phone_numbers, :array, :optional, 'Array of phone numbers to invite to answer this question, sample: [{number: 123123, name: "Owen"}, {number: 090909, name: "Matt"}]'
  end
  def add_people_answer_question
    @content.add_people_answer_question(current_user.id, params[:user_recommended_ids], params[:phone_numbers])
    head :ok
  end

  swagger_api :likes do
    summary 'Return the likes/reactions of current content'
    param :path, :id, :integer, :required, 'Content feed ID'
    param :query, :kind, :string, :optional, 'Permit to filter the kind of reaction: love, wow, pray, amen, angry, sad (default empty and return all reactions)'
  end
  def likes
    if params[:kind].present?
      @users = @content.voters_for(params[:kind]).reorder('voted_at ASC').page(params[:page]).per(20)
    else
      @users = @content.voters.reorder('voted_at ASC').page(params[:page]).per(20)
    end
  end

  swagger_api :share do
    summary 'Shares current content'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def share
    Share.find_or_create_by(user: current_user, content: @content)
    head(:created)
  end

  swagger_api :stop_sharing do
    summary 'Stop sharing current content'
    param :path, :id, :integer, :required, 'Content feed ID'
  end
  def stop_sharing
    share = Share.where(user: current_user, content: @content).take
    if share
      share.destroy
      render(nothing: true)
    else
      render_error_messages ['You are not sharing this content.']
    end
  end

  swagger_api :trending_now do
    summary 'Return trending contents visible for current user'
    param :query, :page, :integer, :optional, 'Page number of pagination'
    param :query, :per_page, :integer, :optional, 'Quantity of items per page used in pagination (default 5)'
  end
  def trending_now
    newsfeed_service = NewsfeedService.new(current_user, params[:page], params[:per_page] || 5)
    @contents = newsfeed_service.popular_content
  end

  swagger_api :content_file_visit do
    summary 'Marks as visited current content file, it means: increment the the quantity of visitors/viewers for current content file.'
    param :path, :id, :integer, :required, 'Content feed ID owner of the file'
    param :path, :file_id, :integer, :required, 'Content file ID'
  end
  def content_file_visit
    file = @content.content_images.find(params[:file_id])
    visit = file.content_file_visitors.new(user: current_user)
    if visit.save
      render json: {visits: file.visits_counter}
    else
      render_error_model visit
    end
  rescue
    render_error_messages ['Content file not found']
  end

  swagger_api :widget_popular_content do
    summary 'Most popular public content on the site in this moment. The period range is last hour.'
    param :query, :page, :integer, :optional, 'Page number of pagination'
    param :query, :per_page, :integer, :optional, 'Quantity of items per page used in pagination (default 4)'
  end
  def widget_popular_content
  end

  private
  def set_public_content
    @content = Content.find(params[:id])
    authorize! :show, @content
  end
  
  def set_content
    @content ||= current_user.contents.find(params[:id])
  end

  def content_params(kind = 'status')
    params[:content_type] = @content.try(:content_type) || kind
    if !params[:id].present? && params[:owner_id].present? && User.find_by_id(params[:owner_id]).present? # on create
      params[:user_id] = params[:owner_id]
      params[:owner_id] = current_user.id
    end
    params[:user_recommended_ids] = params[:user_recommended_ids].split(',') if params[:user_recommended_ids].is_a?(String)
    params[:users_prayer_ids] = params[:users_prayer_ids].split(',') if params[:users_prayer_ids].is_a?(String)
    
    filter = [:description, :privacy_level]
    filter += [:user_id, :owner_id, :content_type, :user_group_id] unless params[:id].present? # on create
    
    case params[:content_type]
      when 'status'
      when 'pray'
        filter += [:title, users_prayer_ids: []]
      when 'image'
        filter += [content_images_attributes: [:image], content_image_ids: []]
      when 'question'
        filter += [:title, user_recommended_ids: []]
    end
    params.permit(filter)
  end
  
  def render_content
    render partial: 'api/v1/pub/contents/content', locals:{content: @content}
  end

  # convert into nil 0 values
  def fix_0_values
    params[:user_group_id] = nil if params[:user_group_id] === 0
    params[:owner_id] = nil if params[:owner_id] === 0
  end
end
