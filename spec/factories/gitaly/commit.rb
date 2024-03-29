# frozen_string_literal: true

FactoryBot.define do
  sequence(:gitaly_commit_id) { Digest::SHA1.hexdigest(Time.now.to_f.to_s) }

  factory :gitaly_commit, class: 'Gitaly::GitCommit' do
    skip_create

    id { generate(:gitaly_commit_id) }
    parent_ids do
      ids = [generate(:gitaly_commit_id), generate(:gitaly_commit_id)]
      Google::Protobuf::RepeatedField.new(:string, ids)
    end
    subject { "My commit" }

    body { subject + "\nMy body" }
    author { association(:gitaly_commit_author) }
    committer { association(:gitaly_commit_author) }

    trailers do
      trailers = body.lines.keep_if { |l| l =~ /.*: / }.map do |l|
        key, value = *l.split(":").map(&:strip)

        Gitaly::CommitTrailer.new(key: key, value: value)
      end

      Google::Protobuf::RepeatedField.new(:message, Gitaly::CommitTrailer, trailers)
    end
  end
end
