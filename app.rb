require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
require 'pry'
require 'rss'
# require 'httparty'     # For our server requests
# require 'securerandom' # To generate random strings for the state variable to prevent CSRF

class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions
  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end
  
  # set the secret yourself, so all your application instances share it:
  # set :session_secret, 'super secret'

  ########################
  # DB Configuration
  ########################
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new({:host => uri.host,
                      :port => uri.port,
                      :password => uri.password})
  # $redis.flushdb

  ########################
  # Routes
  ########################

  get('/') do
    #points the user directly to the posts 
    redirect to("/posts")
  end

  # GET Posts
  get("/posts") do
    id = params["first"].to_i || 0
    posts = $redis.keys("*posts*").map { |post| JSON.parse($redis.get(post)) }
    # subset
    @posts = posts[id,10]
    @posts.sort_by! {|hash| hash["id"] }
    render(:erb, :index)
  end


  # POST /posts
  post("/posts") do
    title = params[:title]
    story = params[:story]
    index = $redis.incr("post:index")
    post = { title: title, story: story, id: index }
    $redis.set("posts:#{index}", post.to_json)
    redirect to("/posts")
  end

  # GET /posts/new
  get("/posts/new") do
    render(:erb, :new_post)
  end

  # GET /posts/1
  get("/posts/:id") do
    id = params[:id]
    raw_post = $redis.get("posts:#{id}")
    @post = JSON.parse(raw_post)
    render(:erb, :post)
  end

  # GET /posts/1/edit
  get("/posts/:id/edit") do
    id = params[:id]
    raw_post = $redis.get("posts:#{id}")
    @post = JSON.parse(raw_post)
    render(:erb, :edit_post)
  end

  # PUT /posts/1
  put("/posts/:id") do
    title = params[:title]
    story = params[:story]
    id = params[:id]
    updated_post = { title: title, story: story, id: id }
    $redis.set("posts:#{id}", updated_post.to_json)
    redirect to("/posts/#{id}")
  end

  # DELETE /posts/1
  delete("/posts/:id") do
    id = params[:id]
    $redis.del("posts:#{id}")
    redirect to("/posts")
  end

  # GET RSS Feed
  get("/rss/:id") do
    title = params[:title]
    id = params[:id]
    rss = RSS::Maker.make("atom") do |maker|
      maker.channel.author = "Will Schjang"
      maker.channel.updated = Time.now.to_s
      maker.channel.about = "localhost:9393.rss"
      maker.channel.title = "Project Feed"

      maker.items.new_item do |item|
        item.link = "/posts/#{id}"
        item.title = "#{title}"
        item.updated = Time.now.to_s
      end
    end

    puts rss    
  end

  # client = OAuth2::Client.new(
  #   APP_ID,
  #   SECRET_ID,
  #   :authorize_url => "/dialog/oauth",
  #   :token_url => "/oauth/access_token",
  #   :site => "https://www.facebook.com/"
  # )

  # code = client.auth_code.authorize_url(:redirect_uri => "http://www.facebook.com/")
  # token = client.auth_code.get_token(code, :redirect_uri => "https://graph.facebook.com/")
  # OAuth2::AccessToken.new(client, token.token, {:mode => :query, :param_name =>"oauth_token"})


  # rss = RSS::Maker.make("atom") do |maker|
  #     maker.channel.author = "Will Schjang"
  #     maker.channel.updated = Time.now.to_s
  #     maker.channel.about = "/.rss"
  #     maker.channel.title = "Project Feed"

  #     maker.items.new_item do |item|
  #       item.link = "/posts#{:id}"
  #       item.title = "posts#{:title}"
  #       item.updated = Time.now.to_s
  #     end
  #   end

  #   puts rss   

  # GET JSON Feed
  get("/as/:id") do
  
  end

  # get("/posts/:id/comments") do
  #   #communicates with redis in order to pull the posts onto the app
  #   #JSON turns data into a hash then it gets mapped into an array
  #   @comments = $redis.keys("*comments*").map { |comment| JSON.parse($redis.get(comment)) }
  #   render(:erb, :_comments)
  # end

  # post("/posts/:id/comments") do
  #   commentor_name = params[:commentor_name]
  #   comment = params[:comment]
  #   index = $redis.incr("comment:index")
  #   user_comment = { commentor_name: commentor_name, comment: comment, id: index }
  #   $redis.set("comments:#{id}", user_comment.to_json)
  #   redirect to("/posts/#{id}")
  # end

  # get("/posts/:id/comments:id") do
  #   id = params[:id]
  #   raw_comment = $redis.get("comments:#{id}")
  #   @comment = JSON.parse(raw_comment)
  #   render(:erb, :_comments)
  # end

end
