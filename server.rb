require 'rubygems'
require 'sinatra/base'
require 'sinatra/content_for'
require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database =>  'data/people.sqlite3.db'
)

connection_handle = ActiveRecord::Base.connection

class People < ActiveRecord::Base
  self.table_name = "people"
end

class Group < ActiveRecord::Base
  def url
    underscore_name = name.downcase.gsub(" ", "-")
    "/group/#{id}-#{underscore_name}"
  end
end

class GuessWho < Sinatra::Base
  helpers Sinatra::ContentFor

  helpers do
    def title
      sub = @group_name
      title = "Guess Who?"
      unless sub.nil?
        title += " | #{sub}"
      end
      return title
    end
  end

  # base route
  get '/' do
    @all_label = ENV["ALL_LABEL"] || "Everyone"
    if max_id = ENV['MAX_GROUP_LIST_ID'].to_i
      @groups = Group.where("id <= ?", max_id)
    else
      @groups = Group.all
    end

    erb :home
  end

  get '/group/list' do
    @all_label = "All Groups"
    @groups = Group.all
    erb :home
  end

  get '/group/:group' do
    @group_id = params[:group].split("-")[0]
    @api_end_point = "/#{@group_id}/random.json"
    @use_original_thumbnail = !!(ENV["ORINGAL_THUMBNAIL"] =~ /true/i)
    @group_name = Group.where(:id => @group_id).first.name rescue "Everyone"
    erb :game
  end

  # logic to get random people
  ['/random.json', '/:group/random.json'].each do |path|
    get path do
      content_type :json

      num = 4
      @correct_id = rand(num)
      @people = People.order("random()").limit(num)

      if params[:group] and not params[:group] =~ /all/i
        @people = @people.where(:group_id => params[:group])
      end

      @correct = @people[@correct_id]

      {
        description: @correct.description,
        original_thumbnail: @correct.thumbnail,
        thumbnail: "/img/thumbnail/#{@correct.id}.jpg",
        web_url: @correct.web_url,
        correct_answer_id: @correct_id.to_i,
        options: @people.map(&:name)
      }.to_json
    end
  end

  after do
    ActiveRecord::Base.connection.close
  end
end
