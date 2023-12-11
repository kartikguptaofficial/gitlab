# frozen_string_literal: true

module CsvBuilder
  class Builder
    UNSAFE_EXCEL_PREFIX = /\A[=\+\-@;]/ # rubocop:disable Style/RedundantRegexpEscape

    attr_reader :rows_written

    def initialize(collection, header_to_value_hash, associations_to_preload = [])
      @header_to_value_hash = header_to_value_hash
      @collection = collection
      @truncated = false
      @rows_written = 0
      @associations_to_preload = associations_to_preload
    end

    # Renders the csv to a string
    def render(truncate_after_bytes = nil)
      Tempfile.open(['csv']) do |tempfile|
        csv = CSV.new(tempfile)

        write_csv csv, until_condition: -> do
          truncate_after_bytes && tempfile.size > truncate_after_bytes
        end

        if block_given?
          yield tempfile
        else
          tempfile.rewind
          tempfile.read
        end
      end
    end

    def truncated?
      @truncated
    end

    def rows_expected
      if truncated? || rows_written.zero?
        @collection.count
      else
        rows_written
      end
    end

    def status
      {
        truncated: truncated?,
        rows_written: rows_written,
        rows_expected: rows_expected
      }
    end

    protected

    def each(&block)
      if @associations_to_preload&.any? && @collection.respond_to?(:each_batch)
        @collection.each_batch(order_hint: :created_at) do |relation|
          relation.preload(@associations_to_preload).order(:id).each(&block)
        end
      elsif @collection.respond_to?(:find_each)
        @collection.find_each(&block)
      else
        @collection.each(&block)
      end
    end

    private

    def headers
      @headers ||= @header_to_value_hash.keys
    end

    def attributes
      @attributes ||= @header_to_value_hash.values
    end

    def row(object)
      attributes.map do |attribute|
        if object.is_a?(Hash)
          excel_sanitize(object[attribute])
        elsif attribute.respond_to?(:call)
          excel_sanitize(attribute.call(object))
        else
          excel_sanitize(object.public_send(attribute)) # rubocop:disable GitlabSecurity/PublicSend
        end
      end
    end

    def write_csv(csv, until_condition:)
      csv << headers

      each do |object|
        csv << row(object)

        @rows_written += 1

        if until_condition.call
          @truncated = true
          break
        end
      end
    end

    def excel_sanitize(line)
      return if line.nil?
      return line unless line.is_a?(String) && line.match?(UNSAFE_EXCEL_PREFIX)

      ["'", line].join
    end
  end
end
