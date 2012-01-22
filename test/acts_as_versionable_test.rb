require 'rubygems'
gem 'activerecord'
require 'active_record'
require 'test/unit'

#require "#{File.dirname(__FILE__)}/../init"
require File.join(File.dirname(__FILE__), '../lib', 'acts_as_versionable')

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :documents do |t|
      t.string :title
      t.text   :body
      t.integer :user_id
      t.integer :version_number
      t.integer :version_id
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Document < ActiveRecord::Base
  acts_as_versionable
end

class VersionableTest < Test::Unit::TestCase
  def setup
    setup_db

    (1..3).each do |m|
      document = Document.create!(:title => m.to_s, :body => m.to_s)
      (1..m*2).each do |v|
        document.title = v.to_s
        document.body = v.to_s
        document.save
      end        
    end    
  end

  def teardown
    teardown_db
  end
  
  def test_documents
    assert_equal 18, Document.all.count
    #Document.last_versions.each do |d|
    #  p "title: #{d.title}     versions: #{d.last_version}"
    #  p "#{d.versions.map &:title}"
    #end  
  end  
  
  def test_if_class_methods_present
    [:last_versions, :get_versionable].each do |method|
      assert_equal true, Document.respond_to?(method)
    end  
  end  
  
  def test_if_mixed_methods_present
    document = Document.first
    [:versions, :get_version, :revert_to_version,
     :last_version, :versionable?, :editable_version,
     :internal_versions, :parent_version].each do |method|
      assert_equal true, document.respond_to?(method) 
    end
  end

  def test_last_versions
    documents = Document.last_versions
    assert_equal 3, documents.count     
  end
  
  def test_initial_versions_of_the_documents
    documents = Document.last_versions

    documents.each do |d|
      assert_equal nil, d.version_number
      assert_equal nil, d.version_id      
    end      
  end
  
  def test_get_versionable
    document = Document.get_versionable(1,2).first
    assert_equal 2, document.version_number
    assert_equal '1', document.title
  end

  def test_versions_created
    document = Document.create(:title => "A", :body => "AAAA")
    assert_equal 1, document.last_version
    assert_equal 1, document.version
    document.title = "B"
    document.save
    assert_equal 2, document.version
  end

  def test_last_version
    documents = Document.last_versions

    assert_equal 3, documents[0].last_version
    assert_equal 5, documents[1].last_version
    assert_equal 7, documents[2].last_version    
  end  
  
  def test_version_change_to_2
    document = Document.last_versions.first    
    assert_not_nil document
    
    assert_equal '2', document.title
    assert_equal 3, document.last_version
    
    document.update_attributes(:title => '4', :body => '4')
    
    assert_equal 4, document.last_version
    assert_equal '4', document.title
    assert_equal '4', document.body
  end

  def test_revert_to_version
    document = Document.last_versions.first    
    assert_not_nil document

    document.update_attributes(:title => '4', :body => '4')
    assert_equal 4, document.last_version
    
    document = document.revert_to_version(1)
    
    assert_equal 5, document.last_version
    assert_equal '1', document.title
    assert_equal '1', document.body

    document = document.revert_to_version(4)

    assert_equal 6, document.last_version
    assert_equal '4', document.title 
    assert_equal '4', document.body
  
    assert_raise ActsAsVersionable::NoSuchVersionError do
      document.revert_to_version(10)
    end
  end


#  def test_new_from_version
#     article = Article.first
#     assert_not_nil article
#     
#     dummy = article.new_from_version 1
#    
#     article.revert_to(1)
#     assert_equal dummy.title, article.title 
#     assert_equal dummy.body, article.body      
#  end  

  def test_versions
    document = Document.last_versions.first    
    assert_not_nil document
          
    assert_equal 3, document.versions.count
    
    document = document.get_version(2)
    assert_equal 3, document.versions.count
  end  

  def test_get_version
    document = Document.last_versions.first    
    assert_not_nil document
          
     first = document.versions[1]
     one = document.get_version(2)
     
     assert_equal first.title, one.title 
     assert_equal first.body, one.body
  end  
  
  def test_get_versions
    document = Document.last_versions.first    
    assert_not_nil document
    
    version2 = document.get_version 2
    assert_equal 2, version2.version    
  end  

  def test_max_versions
    document = Document.last_versions.last
    (1..10).each do |v|
      document.title = v.to_s
      document.save
    end  
    assert_equal 10, document.versions.count
  end  

  def test_dependent_destroy
    Document.last_versions.destroy_all
    assert_equal [], Document.all
  end
  
  def test_modify_versioned
    document = Document.last_versions.first    
    assert_not_nil document
    
    assert_equal 3, document.last_version
    
    version2 = document.get_version 2
    version2.title = "version2 new"
    
    assert_equal false, version2.versionable? 
    
    assert_raise ActsAsVersionable::NonEditableVersionError do
      version2.save
    end
    
    assert_equal 2, version2.version 
    assert_equal "version2 new", version2.title    

    assert_equal 3, document.last_version    
  end  
  
  def test_readme
    # cerate first version
    document = Document.create(:title => 'title', :body => 'body')
    assert_equal 1, document.version
    assert_equal 1, document.last_version
    
    # modify 
    document.title = 'new title'
    document.save
    
    # second version was created
    assert_equal 2, document.version
    assert_equal 2, document.last_version    
    assert_equal 2, document.versions.count
    
    # revert to previous version
    document.revert_to_version(1)     
    assert_equal "title", document.title
    # a new version also is created 
    assert_equal 3, document.version
    
    # get a version
    document = document.get_version(2)
    assert_equal 2, document.version
    assert_equal "new title", document.title

    # revert to a version
    document = document.revert_to_version(2) 
    assert_equal "new title", document.title
    assert_equal 4, document.version
    
    version1 = document.get_version(1)
    assert_equal 1, version1.version
    assert_equal 4, version1.last_version
        
  end
  
end

