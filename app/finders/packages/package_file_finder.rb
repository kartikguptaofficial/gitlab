# frozen_string_literal: true
class Packages::PackageFileFinder
  attr_reader :package, :file_name, :params

  def initialize(package, file_name, params = {})
    @package = package
    @file_name = file_name
    @params = params
  end

  def execute
    package_files.last
  end

  def execute!
    package_files.last!
  end

  private

  def package_files
    files = if Feature.enabled?(:packages_installable_package_files, default_enabled: :yaml)
              package.installable_package_files
            else
              package.package_files
            end

    by_file_name(files)
  end

  def by_file_name(files)
    if params[:with_file_name_like]
      files.with_file_name_like(file_name)
    else
      files.with_file_name(file_name)
    end
  end
end
