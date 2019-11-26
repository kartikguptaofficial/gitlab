# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Diff::HighlightCache, :clean_gitlab_redis_cache do
  let(:merge_request) { create(:merge_request_with_diffs) }
  let(:diff_hash) do
    { ".gitignore-false-false-false" =>
      [{ line_code: nil, rich_text: nil, text: "@@ -17,3 +17,4 @@ rerun.txt", type: "match", index: 0, old_pos: 17, new_pos: 17 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_17_17",
        rich_text: " <span id=\"LC17\" class=\"line\" lang=\"plaintext\">pickle-email-*.html</span>\n",
        text: " pickle-email-*.html",
        type: nil,
        index: 1,
        old_pos: 17,
        new_pos: 17 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_18_18",
        rich_text: " <span id=\"LC18\" class=\"line\" lang=\"plaintext\">.project</span>\n",
        text: " .project",
        type: nil,
        index: 2,
        old_pos: 18,
        new_pos: 18 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_19_19",
        rich_text: " <span id=\"LC19\" class=\"line\" lang=\"plaintext\">config/initializers/secret_token.rb</span>\n",
        text: " config/initializers/secret_token.rb",
        type: nil,
        index: 3,
        old_pos: 19,
        new_pos: 19 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_20_20",
        rich_text: "+<span id=\"LC20\" class=\"line\" lang=\"plaintext\">.DS_Store</span>",
        text: "+.DS_Store",
        type: "new",
        index: 4,
        old_pos: 20,
        new_pos: 20 }] }
  end

  let(:cache_key) { cache.key }

  subject(:cache) { described_class.new(merge_request.diffs, backend: backend) }

  describe '#decorate' do
    let(:backend) { double('backend').as_null_object }

    # Manually creates a Diff::File object to avoid triggering the cache on
    # the FileCollection::MergeRequestDiff
    let(:diff_file) do
      diffs = merge_request.diffs
      raw_diff = diffs.diffable.raw_diffs(diffs.diff_options.merge(paths: ['CHANGELOG'])).first
      Gitlab::Diff::File.new(raw_diff,
                             repository: diffs.project.repository,
                             diff_refs: diffs.diff_refs,
                             fallback_diff_refs: diffs.fallback_diff_refs)
    end

    it 'does not calculate highlighting when reading from cache' do
      cache.write_if_empty
      cache.decorate(diff_file)

      expect_any_instance_of(Gitlab::Diff::Highlight).not_to receive(:highlight)

      diff_file.highlighted_diff_lines
    end

    it 'assigns highlighted diff lines to the DiffFile' do
      cache.write_if_empty
      cache.decorate(diff_file)

      expect(diff_file.highlighted_diff_lines.size).to be > 5
    end
  end

  describe '#write_if_empty' do
    let(:backend) { double('backend', read: {}).as_null_object }

    xit 'submits a single write action to the redis cache when invoked multiple times' do
      expect(cache).to receive(:write_to_redis_hash).once

      2.times { cache.write_if_empty }
    end
  end

  describe '#write_to_redis_hash' do
    let(:backend) { Rails.cache }

    it 'creates or updates a Redis hash' do
      expect { cache.write_to_redis_hash(diff_hash) }
        .to change { Gitlab::Redis::Cache.with { |r| r.hgetall(cache_key) } }
    end
  end

  describe '#read_single_entry_from_redis_hash' do
    let(:backend) { Rails.cache }

    before do
      cache.write_to_redis_hash(diff_hash)
    end

    it 'returns highlighted diff content for a single file as JSON' do
      diff_hash.each do |file_path, value|
        found = cache.read_single_entry_from_redis_hash(file_path)

        expect(found).to eq(value.to_json)
      end
    end
  end

  describe '#clear' do
    let(:backend) { double('backend').as_null_object }

    it 'clears cache' do
      expect_any_instance_of(Redis).to receive(:del).with(cache_key)

      cache.clear
    end
  end
end
