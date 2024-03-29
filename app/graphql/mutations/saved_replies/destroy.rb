# frozen_string_literal: true

module Mutations
  module SavedReplies
    class Destroy < Base
      graphql_name 'SavedReplyDestroy'

      authorize :destroy_saved_replies

      argument :id, Types::GlobalIDType[::Users::SavedReply],
               required: true,
               description: copy_field_description(Types::SavedReplyType, :id)

      def resolve(id:)
        saved_reply = authorized_find!(id: id)
        result = ::Users::SavedReplies::DestroyService.new(saved_reply: saved_reply).execute
        present_result(result)
      end
    end
  end
end
