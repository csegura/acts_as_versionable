require "acts_as_versionable/version"

module ActsAsVersionable

  class NoSuchVersionError < Exception
  end

  extend ActiveSupport::Concern

  included do |base|    
  end

  module ClassMethods
    def acts_as_versionable(options = {})
      cattr_accessor :max_versions
      self.max_versions = (options[:max_versions] || 10)

      after_save :create_new_version

      has_many :internal_versions,
               :class_name => self.name,
               :foreign_key => "version_id",
               :order => "version_number desc",
               :dependent => :destroy
      
      belongs_to :parent_version, :class_name => self.name, :foreign_key => "version_id" 
      
      scope :last_versions, where(:version_id => nil)
      scope :get_versionable, lambda { |id, version| where(:version_id => id, :version_number => version) }
            
      include InstanceMethods
    end             
  end

  module InstanceMethods  
    def revert_to_version(number)
      version = get_version number
      editable = last_version_editable
      copy_version_values version, editable
      editable.version_number = nil
      editable.version_id = nil
      editable.save
      editable
    end

    # return a determined version number
    def get_version(number)
      version = versions.where(:version_number => number).first
      raise NoSuchVersionError if version.nil?
      version
    end

    # return an array with all versions
    def versions
      if versionable?
        internal_versions
      else
        self.class.where(:version_id => self.version_id).order(:version_number).reverse_order
      end
    end

    # check if we are in main version
    def versionable?
      version_id.nil?
    end

    # return the current version
    def version
      return last_version if versionable?
      version_number
    end  

    # return the last version number
    def last_version
      return 0 if versions.count == 0
      versions.first.version_number 
    end

    private

    # return the last version editable
    def last_version_editable
      parent_version.nil? ? self : parent_version        
    end
    
    # callback after save
    def create_new_version
      if versionable?
       
        cloned = copy_version_values self, self.class.new
        cloned.version_id = self.id
        cloned.version_number = last_version + 1
        cloned.save
        
        # purge max limit
        excess_baggage = cloned.version_number - max_versions
        if excess_baggage > 0
          versions.where("version_number <= ?", excess_baggage).delete_all
        end
      end
    end

    def copy_version_values(from, to)
      columns = self.class.columns.reject { |c| c.name == "id" }
      columns.each {|c| to[c.name] = from[c.name] }
      to
    end
  end

end

ActiveRecord::Base.send :extend, ActsAsVersionable::ClassMethods
