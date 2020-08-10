# frozen_string_literal: true

# NuGet Package Manager Client API
#
# These API endpoints are not meant to be consumed directly by users. They are
# called by the NuGet package manager client when users run commands
# like `nuget install` or `nuget push`.
module API
  class NugetPackages < Grape::API::Instance
    helpers ::API::Helpers::PackagesManagerClientsHelpers
    helpers ::API::Helpers::Packages::BasicAuthHelpers

    POSITIVE_INTEGER_REGEX = %r{\A[1-9]\d*\z}.freeze
    NON_NEGATIVE_INTEGER_REGEX = %r{\A0|[1-9]\d*\z}.freeze

    PACKAGE_FILENAME = 'package.nupkg'

    default_format :json

    rescue_from ArgumentError do |e|
      render_api_error!(e.message, 400)
    end

    helpers do
      def find_packages
        packages = package_finder.execute

        not_found!('Packages') unless packages.exists?

        packages
      end

      def find_package
        package = package_finder(package_version: params[:package_version]).execute
                                                                           .first

        not_found!('Package') unless package

        package
      end

      def package_finder(finder_params = {})
        ::Packages::Nuget::PackageFinder.new(
          authorized_user_project,
          finder_params.merge(package_name: params[:package_name])
        )
      end
    end

    before do
      require_packages_enabled!
    end

    params do
      requires :id, type: String, desc: 'The ID of a project', regexp: POSITIVE_INTEGER_REGEX
    end

    route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      before do
        authorized_user_project
      end

      namespace ':id/packages/nuget' do
        # https://docs.microsoft.com/en-us/nuget/api/service-index
        desc 'The NuGet Service Index' do
          detail 'This feature was introduced in GitLab 12.6'
        end

        route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

        get 'index', format: :json do
          authorize_read_package!(authorized_user_project)

          track_event('nuget_service_index')

          present ::Packages::Nuget::ServiceIndexPresenter.new(authorized_user_project),
            with: ::API::Entities::Nuget::ServiceIndex
        end

        # https://docs.microsoft.com/en-us/nuget/api/package-publish-resource
        desc 'The NuGet Package Publish endpoint' do
          detail 'This feature was introduced in GitLab 12.6'
        end

        params do
          requires :package, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)'
        end

        route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

        put do
          authorize_upload!(authorized_user_project)

          file_params = params.merge(
            file: params[:package],
            file_name: PACKAGE_FILENAME
          )

          package = ::Packages::Nuget::CreatePackageService.new(authorized_user_project, current_user)
                                                           .execute

          package_file = ::Packages::CreatePackageFileService.new(package, file_params)
                                                             .execute

          track_event('push_package')

          ::Packages::Nuget::ExtractionWorker.perform_async(package_file.id) # rubocop:disable CodeReuse/Worker

          created!
        rescue ObjectStorage::RemoteStoreError => e
          Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: authorized_user_project.id })

          forbidden!
        end

        route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

        put 'authorize' do
          authorize_workhorse!(subject: authorized_user_project, has_length: false)
        end

        params do
          requires :package_name, type: String, desc: 'The NuGet package name', regexp: API::NO_SLASH_URL_PART_REGEX
        end
        namespace '/metadata/*package_name' do
          before do
            authorize_read_package!(authorized_user_project)
          end

          # https://docs.microsoft.com/en-us/nuget/api/registration-base-url-resource
          desc 'The NuGet Metadata Service - Package name level' do
            detail 'This feature was introduced in GitLab 12.8'
          end

          route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

          get 'index', format: :json do
            present ::Packages::Nuget::PackagesMetadataPresenter.new(find_packages),
                    with: ::API::Entities::Nuget::PackagesMetadata
          end

          desc 'The NuGet Metadata Service - Package name and version level' do
            detail 'This feature was introduced in GitLab 12.8'
          end
          params do
            requires :package_version, type: String, desc: 'The NuGet package version', regexp: API::NO_SLASH_URL_PART_REGEX
          end

          route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

          get '*package_version', format: :json do
            present ::Packages::Nuget::PackageMetadataPresenter.new(find_package),
                    with: ::API::Entities::Nuget::PackageMetadata
          end
        end

        # https://docs.microsoft.com/en-us/nuget/api/package-base-address-resource
        params do
          requires :package_name, type: String, desc: 'The NuGet package name', regexp: API::NO_SLASH_URL_PART_REGEX
        end
        namespace '/download/*package_name' do
          before do
            authorize_read_package!(authorized_user_project)
          end

          desc 'The NuGet Content Service - index request' do
            detail 'This feature was introduced in GitLab 12.8'
          end

          route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

          get 'index', format: :json do
            present ::Packages::Nuget::PackagesVersionsPresenter.new(find_packages),
                    with: ::API::Entities::Nuget::PackagesVersions
          end

          desc 'The NuGet Content Service - content request' do
            detail 'This feature was introduced in GitLab 12.8'
          end
          params do
            requires :package_version, type: String, desc: 'The NuGet package version', regexp: API::NO_SLASH_URL_PART_REGEX
            requires :package_filename, type: String, desc: 'The NuGet package filename', regexp: API::NO_SLASH_URL_PART_REGEX
          end

          route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

          get '*package_version/*package_filename', format: :nupkg do
            filename = "#{params[:package_filename]}.#{params[:format]}"
            package_file = ::Packages::PackageFileFinder.new(find_package, filename, with_file_name_like: true)
                                                        .execute

            not_found!('Package') unless package_file

            track_event('pull_package')

            # nuget and dotnet don't support 302 Moved status codes, supports_direct_download has to be set to false
            present_carrierwave_file!(package_file.file, supports_direct_download: false)
          end
        end

        params do
          requires :q, type: String, desc: 'The search term'
          optional :skip, type: Integer, desc: 'The number of results to skip', default: 0, regexp: NON_NEGATIVE_INTEGER_REGEX
          optional :take, type: Integer, desc: 'The number of results to return', default: Kaminari.config.default_per_page, regexp: POSITIVE_INTEGER_REGEX
          optional :prerelease, type: Boolean, desc: 'Include prerelease versions', default: true
        end
        namespace '/query' do
          before do
            authorize_read_package!(authorized_user_project)
          end

          # https://docs.microsoft.com/en-us/nuget/api/search-query-service-resource
          desc 'The NuGet Search Service' do
            detail 'This feature was introduced in GitLab 12.8'
          end

          route_setting :authentication, deploy_token_allowed: true, job_token_allowed: :basic_auth

          get format: :json do
            search_options = {
              include_prerelease_versions: params[:prerelease],
              per_page: params[:take],
              padding: params[:skip]
            }
            search = Packages::Nuget::SearchService
              .new(authorized_user_project, params[:q], search_options)
              .execute

            track_event('search_package')

            present ::Packages::Nuget::SearchResultsPresenter.new(search),
              with: ::API::Entities::Nuget::SearchResults
          end
        end
      end
    end
  end
end
