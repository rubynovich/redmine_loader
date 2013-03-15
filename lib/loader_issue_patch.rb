require_dependency 'issue'

module LoaderPlugin
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      base.class_eval do
        safe_attributes 'uid'
      end
    end

    module ClassMethods

    end

    module InstanceMethods
    end
  end
end
