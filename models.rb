require 'rubygems'
require 'redis'
require 'singleton'

BOOK_STRING_ATTRS = %w(title isbn description price pages)


class RedisHub < Redis

  include Singleton
  
  def initialize
    super
  end
  
end


class Book
  attr_reader :id
  attr_accessor :title, :isbn, :description, :price, :pages, :authors, :topics

  def initialize(options = {})
    @hub = RedisHub.instance

    @id = options[:id].nil? ? @hub.incr('book:next_id') : options[:id]
    @title = options[:title] unless options[:title].nil?
    @isbn = options[:isbn] unless options[:isbn].nil?
    @description = options[:description] unless options[:description].nil?
    @price = options[:price] unless options[:price].nil?
    @pages = options[:pages] unless options[:pages].nil?
    @authors = options[:authors] unless options[:authors].nil?
    @topics = options[:topics] unless options[:topics].nil?
  end

  # given a book_id, returns the corresponding book object with all
  # the attributes loaded from Redis; if the book_id does not exists,
  # it returns nil.
  def self.get(id)
    hub = RedisHub.instance

    if hub.get("book:#{id}:title")
      book = Book.new(:id => id)
    else
      return nil
    end
    
    book.authors = Book.get_book_authors(id) 
    book.topics = Book.get_book_topics(id)  
    BOOK_STRING_ATTRS.each do |attr|
      book.send "#{attr}=".to_sym, hub.get("book:#{id}:#{attr}")
    end
    
    book
  end

  # returns an array of book objects corresponding to all the book_id
  # available in our Redis book:list key
  def self.get_all
    books = []
    RedisHub.instance.lrange('book:list', 0, -1).each do |book_id|
      books.push(Book.get(book_id))
    end

    books
  end

  # save the book object in Redis
  def save
    # add the id to the book list
    @hub.lpush('book:list', @id)

    # creates the couples key-values where we store our data
    BOOK_STRING_ATTRS.each do |attr|
      @hub.set("book:#{@id}:#{attr}", self.send(attr.to_sym))
    end

    # creates a set containing all the topic id associated to our book
    # and add the book id to the set of all the books belonging to the
    # same topic
    @topics.each do |topic|
      tid = (topic.is_a?(Book)) ? topic.id : topic
      @hub.sadd("book:#{@id}:topics", tid)
      Topic.add_book(tid, id)
    end
        
    # create a set containing all the authors id of our book and add
    # the book id to the set of all the books belonging to the same
    # author
    @authors.each do |author|
      aid = (author.is_a?(Author)) ? author.id : author
      @hub.sadd("book:#{@id}:authors", author)
      Author.add_book(author, id)
    end
  end

  # given a book_id, delete all keys associated with it from the Redis
  # database
  def self.remove(id)
    hub = RedisHub.instance
 
    BOOK_STRING_ATTRS.each do |attr|
      hub.del("book:#{id}:#{attr}")
    end    

    Book.get_book_topics(id).each do |topic|
      Topic.remove_book(topic.id, id)
    end
    hub.del("book:#{id}:topics")

    Book.get_book_authors(id).each do |author|
      Author.remove_book(author.id, id)
    end
    hub.del("book:#{id}:authors")

    hub.lrem('book:list', 1, id)
  end

  # returns an array with all the book objects available in the
  # book:list key between start and stop
  def self.get_books_range(start, stop)
    books = []
    RedisHub.instance.lrange('book:list', start, stop).each do |book_id|
      books.push(Book.get(book_id))
    end

    books
  end

  # returns an array with all the topic objects relative to the given
  # book_id
  def self.get_book_topics(id)
    topics = []
    RedisHub.instance.smembers("book:#{id}:topics").each do |topic_id|
      topics.push(Topic.get(topic_id))
    end

    topics
  end

  # returns an array with all the author objects relative to the given
  # book_id
  def self.get_book_authors(id)
    authors = []
    RedisHub.instance.smembers("book:#{id}:authors").each do |author_id|
      authors.push(Author.get(author_id))
    end

    authors
  end
end

class Topic
  attr_reader :id
  attr_accessor :name, :description, :books

  def initialize(options = {})
    @hub = RedisHub.instance

    @id = options[:id].nil? ? @hub.incr('topic:next_id') : options[:id]
    @name = options[:name] unless options[:name].nil?
    @description = options[:description] unless options[:description].nil?
    @books = options[:books] || []
  end

  def self.get(id)
    hub = RedisHub.instance

    if hub.get("topic:#{id}:name")
      topic = Topic.new(:id => id)
    else
      return nil
    end
    
    topic.name = hub.get("topic:#{id}:name")
    topic.description = hub.get("topic:#{id}:description")
    topic.books = hub.smembers("topic:#{id}:books")

    topic
  end

  def self.get_all
    topics = []
    RedisHub.instance.lrange('topic:list', 0, -1).each do |topic_id|
      topics.push(Topic.get(topic_id))
    end

    topics
  end

  def save
    @hub.lpush('topic:list', @id)

    @hub.set("topic:#{@id}:name", @name)
    @hub.set("topic:#{@id}:description", @description)
    @books.each do |book|
      @hub.sadd("topic:#{id}:books", book)
    end
  end

  def self.add_book(topic_id, book_id)
    RedisHub.instance.sadd("topic:#{topic_id}:books", book_id)
  end

  def self.remove_book(topic_id, book_id)
    RedisHub.instance.srem("topic:#{topic_id}:books", book_id)
  end

  def self.remove(id)
    hub = RedisHub.instance
    hub.del("topic:#{id}:name")
    hub.del("topic:#{id}:description")

    hub.smembers("topic:#{id}:books").each do |book_id|
      hub.srem("book:#{book_id}:topics", id)
    end
    hub.del("topic:#{id}:books")

    hub.lrem('topic:list', 1, id)
  end
end


class Author
  attr_reader :id
  attr_accessor :name, :surname, :books

  def initialize(options = {})
    @hub = RedisHub.instance
    
    @id = options[:id].nil? ? @hub.incr('author:next_id') : options[:id]
    @name = options[:name] unless options[:name].nil?
    @surname = options[:surname] unless options[:surname].nil?
    @books = options[:books] || []
  end

  def self.get(id)
    hub = RedisHub.instance

    if hub.get("author:#{id}:name")
      author = Author.new(:id => id)
    else
      return nil
    end
    
    author.name = hub.get("author:#{id}:name")
    author.surname = hub.get("author:#{id}:surname")
    author.books = hub.smembers("author:#{id}:books")

    author
  end

  def self.get_all
    authors = []
    RedisHub.instance.lrange('author:list', 0, -1).each do |author_id|
      authors.push(Author.get(author_id))
    end

    authors
  end

  def save
    @hub.lpush('author:list', @id)

    @hub.set("author:#{@id}:name", @name)
    @hub.set("author:#{@id}:surname", @surname)
    @books.each do |book|
      @hub.sadd("author:#{@id}:books", book)
    end
  end

  def self.add_book(author_id, book_id)
    RedisHub.instance.sadd("author:#{author_id}:books", book_id)
  end

  def self.remove_book(author_id, book_id)
    RedisHub.instance.srem("author:#{author_id}:books", book_id)
  end  
  
  def self.remove(id)
    hub = RedisHub.instance

    hub.del("author:#{id}:name")
    hub.del("author:#{id}:surname")
    
    hub.smembers("author:#{id}:books").each do |book_id|
      hub.srem("book:#{book_id}:authors", id)
    end
    hub.del("author:#{id}:books")

    hub.lrem('author:list', 1, id)
  end
end
