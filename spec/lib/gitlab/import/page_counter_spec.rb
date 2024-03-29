# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Import::PageCounter, :clean_gitlab_redis_cache, feature_category: :importers do
  let(:project) { instance_double(Project, id: 1) }
  let(:counter) { described_class.new(project, :issues) }

  describe '#initialize' do
    it 'sets the initial page number to 1 when no value is cached' do
      expect(counter.current).to eq(1)
    end

    it 'sets the initial page number to the cached value when one is present' do
      Gitlab::Cache::Import::Caching.write(counter.cache_key, 2)

      expect(described_class.new(project, :issues).current).to eq(2)
    end

    context 'when gists import' do
      let(:user) { instance_double('User', id: 2) }

      it 'uses gists specific key' do
        result = described_class.new(user, :gists, 'github-gists-importer')

        expect(result.cache_key).to eq('github-gists-importer/page-counter/2/gists')
      end
    end
  end

  describe '#set' do
    it 'overwrites the page number when the given number is greater than the current number' do
      counter.set(4)
      expect(counter.current).to eq(4)
    end

    it 'does not overwrite the page number when the given number is lower than the current number' do
      counter.set(2)
      counter.set(1)

      expect(counter.current).to eq(2)
    end
  end

  describe '#expire!' do
    it 'expires the current page counter' do
      counter.set(2)

      counter.expire!

      expect(Gitlab::Cache::Import::Caching.read_integer(counter.cache_key)).to be_nil
      expect(counter.current).to eq(1)
    end
  end
end
