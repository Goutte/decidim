# frozen_string_literal: true

module Decidim
  module Votings
    class Voting < ApplicationRecord
      include Traceable
      include Loggable
      include Decidim::Participable
      include Decidim::ParticipatorySpaceResourceable
      include Decidim::Randomable
      include Decidim::Searchable
      include Decidim::TranslatableResource
      include Decidim::ScopableParticipatorySpace
      include Decidim::Publicable
      include Decidim::HasUploadValidations

      translatable_fields :title, :description

      belongs_to :organization,
                 foreign_key: "decidim_organization_id",
                 class_name: "Decidim::Organization"

      has_many :components, as: :participatory_space, dependent: :destroy

      validates :slug, uniqueness: { scope: :organization }
      validates :slug, presence: true, format: { with: Decidim::Votings::Voting.slug_format }

      validates_upload :banner_image
      mount_uploader :banner_image, Decidim::BannerImageUploader

      validates_upload :introductory_image
      mount_uploader :introductory_image, Decidim::BannerImageUploader

      scope :upcoming, -> { published.where("start_time > ?", Time.now.utc) }
      scope :active, lambda {
        published
          .where("start_time <= ?", Time.now.utc)
          .where("end_time >= ?", Time.now.utc)
      }
      scope :finished, -> { published.where("end_time < ?", Time.now.utc) }
      scope :order_by_most_recent, -> { order(created_at: :desc) }

      def upcoming?
        start_time > Time.now.utc
      end

      def active?
        start_time <= Time.now.utc && end_time >= Time.now.utc
      end

      def finished?
        end_time < Time.now.utc
      end

      def period_status
        if finished?
          :finished
        elsif active?
          :ongoing
        else
          :upcoming
        end
      end

      searchable_fields({
                          scope_id: :decidim_scope_id,
                          participatory_space: :itself,
                          A: :title,
                          B: :description,
                          datetime: :published_at
                        },
                        index_on_create: ->(_voting) { false },
                        index_on_update: ->(voting) { voting.visible? })

      def self.log_presenter_class_for(_log)
        Decidim::Votings::AdminLog::VotingPresenter
      end

      # Allow ransacker to search for a key in a hstore column (`title`.`en`)
      ransacker :title do |parent|
        Arel::Nodes::InfixOperation.new("->>", parent.table[:title], Arel::Nodes.build_quoted(I18n.locale.to_s))
      end

      def to_param
        slug
      end
    end
  end
end