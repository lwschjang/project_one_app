require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
require 'pry'
require 'redis_pagination'

class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions
  end

  RedisPagination.configure do |configuration|
  configuration.redis = Redis.new
  configuration.page_size = 10
  end
  
  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  ########################
  # DB Configuration
  ########################
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new({:host => uri.host,
                      :port => uri.port,
                      :password => uri.password})


  ########################
  # Routes
  ########################

  get('/') do
    #points the user directly to the posts 
    redirect to("/posts")
  end

  # GET Posts
  get("/posts") do
    #communicates with redis in order to pull the posts onto the app
    #JSON turns data into a hash then it gets mapped into an array
    @posts = $redis.keys("*posts*").map { |post| JSON.parse($redis.get(post)) }
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
