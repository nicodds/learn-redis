require 'models.rb'
require 'sinatra'
require 'erb'


helpers do
  def formatted_list(list, base_url)
    formatted_string = ''
    list.each do |item|
      formatted_string += "<a href=\"#{base_url}/#{item[:id]}\">#{item[:text]}</a>, "
    end

    formatted_string[0..-3]
  end

  def formatted_author_list(list)
    formatted_list(list, '/authors/show')
  end

  def formatted_topic_list(list)
    formatted_list(list, '/topics/show')
  end
end


# books
get '/' do
  redirect '/books/list/0'
end

get '/books/list/:start' do
  @start = (params[:start].nil? or params[:start] == '') ? 0 : params[:start]
  @books = Book.get_books_range(@start.to_i, @start.to_i+9)

  erb 'books/list'.to_sym
end

get '/books/show/:id' do
  @book = Book.get(params[:id])
  erb 'books/show'.to_sym
end

get '/books/add' do
  @authors = Author.get_all
  @topics = Topic.get_all
  erb 'books/add'.to_sym
end

post '/books/save' do
  book = Book.new(:title => params[:title], :topics => params[:topics], 
                  :authors => params[:authors], :isbn => params[:isbn], 
                  :pages => params[:pages], :price => params[:price],
                  :description => params[:description])
  book.save

  redirect '/books/show/'+book.id.to_s
end

get '/books/remove/:id' do
  Book.remove(params[:id])
  
  redirect '/'
end

# topics
get '/topics' do
  topics = Topic.get_all
  max = 1

  topics.each do |topic|
    max = topic.books.size if topic.books.size > max
  end
  
  @tags = topics.map do |topic|
    size = (topic.books.size == 0) ? 90 : topic.books.size.to_f * 300.0 / max.to_f 
    {:id => topic.id, :text => "<span style=\"font-size: #{size}%\">#{topic.name}</span>"}
  end

  erb 'topics/list'.to_sym
end

get '/topics/show/:id' do
  @topic = Topic.get(params[:id])
  @books = []

  @topic.books.each do |book_id|
    @books.push(Book.get(book_id))
  end

  erb 'topics/show'.to_sym
end

get '/topics/add' do
  erb 'topics/add'.to_sym
end

post '/topics/save' do
  topic = Topic.new(:name => params[:name], :description => params[:description])
  topic.save

  redirect '/topics'
end

get '/topics/remove/:id' do
  Topic.remove(params[:id])

  redirect '/topics'
end


# authors
get '/authors' do
  authors = Author.get_all
  max = 1

  authors.each do |author|
    max = author.books.size if author.books.size > max
  end
  
  @tags = authors.map do |author|
    size = (author.books.size == 0) ? 90 : author.books.size.to_f * 300.0 / max.to_f 
    {:id => author.id, :text =>"<span style=\"font-size: #{size}%\">#{author.name} #{author.surname}</span>"}
  end

  erb 'authors/list'.to_sym
end

get '/authors/show/:id' do
  @author = Author.get(params[:id])
  @books = []

  @author.books.each do |book_id|
    @books.push(Book.get(book_id))
  end

  erb 'authors/show'.to_sym
end

get '/authors/add' do
  erb 'authors/add'.to_sym
end

post '/authors/save' do
  author = Author.new(:name => params[:name], :surname => params[:surname])
  author.save

  redirect '/authors'
end

get '/authors/remove/:id' do
  Author.remove(params[:id])

  redirect '/authors'
end
