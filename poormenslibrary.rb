require 'library.rb'
require 'sinatra'
require 'json'
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

  erb :books_list
end

get '/books/show/:id' do
  @book = Book.get(params[:id])
  erb :books_show
end

get '/books/add' do
  @authors = Author.get_all
  @topics = Topic.get_all
  erb :books_add
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
    next if topic.nil?
    max = topic.books.size if topic.books.size > max
  end
  
  @tags = topics.map do |topic|
    size = (topic.books.size == 0) ? 100 : topic.books.size.to_f * 300.0 / max.to_f 

    {:id => topic.id, :text =>"<span style=\"font-size: #{size}%\">#{topic.name}</span>"}
  end

  formatted_topic_list(@tags)
end

get '/topics/books/:id' do
  
end

get '/topics/list' do

end

get '/topics/show/:id' do

end

post '/topics/add' do

end

get '/topics/remove/:id' do

end


# authors
get '/authors' do
  authors = Author.get_all
  max = 1

  authors.each do |author|
    next if author.nil?
    max = author.books.size if author.books.size > max
  end
  
  @tags = authors.map do |author|
    next if author.nil?
    size = (author.books.size == 0) ? 100 : author.books.size.to_f * 300.0 / max.to_f 

    {:id => author.id, :text =>"<span style=\"font-size: #{size}%\">#{author.name} #{author.surname}</span>"}
  end

  formatted_author_list(@tags)
end

get '/authors/books/:id' do

end

get '/authors/list' do

end

get '/authors/show/:id' do

end

post '/authors/add' do

end

get '/authors/remove/:id' do

end
