module Openshift
  module Mock
    class Entity
      attr_reader :namespace, :name, :uid, :resourceVersion,
                  :creationTimestamp, :deletionTimestamp

      def initialize
        @namespace = "mock-namespace" #Namespace's tmp name

        @name = "Define in subclass"
        @uid = SecureRandom.uuid
        @resourceVersion = "1"
        @creationTimestamp = Time.now.utc
        @deletionTimestamp = nil
      end

      def metadata
        self
      end
    end
  end
end
