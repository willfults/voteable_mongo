require 'voteable_mongo/voting'
require 'voteable_mongo/integrations/mongoid'
require 'voteable_mongo/integrations/mongo_mapper'

module Mongo
  module Voteable
    extend ActiveSupport::Concern

    DEFAULT_VOTES = {
      'up' => [],
      'down' => [],
      'up_count' => 0,
      'down_count' => 0,
      'count' => 0,
      'point' => 0
    }

    included do
      include ::Mongo::Voteable::Voting
      include ::Mongo::Voteable::Integrations::Mongoid if defined?(Mongoid)
      include ::Mongo::Voteable::Integrations::MongoMapper if defined?(MongoMapper)
    end

    # How many points should be assigned for each up or down vote and other options
    # This hash should manipulated using voteable method
    VOTEABLE = {}

    module ClassMethods
      # Set vote point for each up (down) vote on an object of this class
      # 
      # @param [Hash] options a hash containings:
      # 
      # voteable self, :up => +1, :down => -3
      # voteable Post, :up => +2, :down => -1, :update_counters => false # skip counter update
      def voteable(klass = self, options = nil)
        VOTEABLE[name] ||= {}
        VOTEABLE[name][klass.name] ||= options
        if klass == self
          if options[:index] == true
            create_voteable_indexes
          end
        else
          VOTEABLE[name][name][:update_parents] ||= true
        end
      end
      
      # Check if voter_id do a vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def voted?(options)
        validate_and_normalize_vote_options(options)
        up_voted?(options) || down_voted?(options)
      end
      
      # Check if voter_id do an up vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def up_voted?(options)
        validate_and_normalize_vote_options(options)
        up_voted_by(options[:voter_id]).where(:_id => options[:votee_id]).count == 1
      end
      
      # Check if voter_id do a down vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def down_voted?(options)
        validate_and_normalize_vote_options(options)
        down_voted_by(options[:voter_id]).where(:_id => options[:votee_id]).count == 1
      end
    end
    
    module InstanceMethods
      # Make a vote on this votee
      #
      # @param [Hash] options a hash containings:
      #   - :voter_id: the voter document id
      #   - :value: vote :up or vote :down
      #   - :revote: change from vote up to vote down
      #   - :unvote: unvote the vote value (:up or :down)
      def vote(options)
        options[:votee_id] = id
        options[:votee] = self
        options[:voter_id] ||= options[:voter].id

        if options[:unvote]
          options[:value] ||= vote_value(options[:voter_id])
        else
          options[:revote] ||= vote_value(options[:voter_id]).present?
        end

        self.class.vote(options)
      end
    
      # Get a voted value on this votee
      #
      # @param [Mongoid Object, BSON::ObjectId] voter is Mongoid object or the id of the voter who made the vote
      def vote_value(voter)
        voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter.id
        return :up if up_voter_ids.include?(voter_id)
        return :down if down_voter_ids.include?(voter_id)
      end
    
      def voted_by?(voter)
        !!vote_value(voter)
      end

      # Array of up voter ids
      def up_voter_ids
        votes.try(:[], 'up') || []
      end

      # Array of down voter ids
      def down_voter_ids
        votes.try(:[], 'down') || []
      end

      # Array of voter ids
      def voter_ids
        up_voter_ids + down_voter_ids
      end

      # Get the number of up votes
      def up_votes_count
        votes.try(:[], 'up_count') || 0
      end
  
      # Get the number of down votes
      def down_votes_count
        votes.try(:[], 'down_count') || 0
      end
  
      # Get the number of votes
      def votes_count
        votes.try(:[], 'count') || 0
      end
  
      # Get the votes point
      def votes_point
        votes.try(:[], 'point') || 0
      end

      # Get up voters
      def up_voters(klass)
        klass.where(:_id => { '$in' =>  up_voter_ids })
      end

      # Get down voters
      def down_voters(klass)
        klass.where(:_id => { '$in' => down_voter_ids })
      end

      # Get voters
      def voters(klass)
        klass.where(:_id => { '$in' => voter_ids })
      end
    end
  end
end