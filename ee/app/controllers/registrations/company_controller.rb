# frozen_string_literal: true

module Registrations
  class CompanyController < ApplicationController
    layout 'minimal'

    before_action :check_if_gl_com_or_dev
    before_action :authenticate_user!
    feature_category :onboarding

    def new
    end

    def create
      result = GitlabSubscriptions::CreateTrialOrLeadService.new(user: current_user, params: permitted_params).execute

      if result.success?
        redirect_to new_users_sign_up_groups_project_path(redirect_param)
      else
        flash.now[:alert] = result[:message]
        render :new, status: result.http_status
      end
    end

    private

    def permitted_params
      params.permit(
        :company_name,
        :company_size,
        :phone_number,
        :country,
        :state,
        :website_url,
        # passed through params
        :role,
        :registration_objective,
        :jobs_to_be_done_other,
        :trial
      )
    end

    def redirect_param
      if params[:trial] == 'true'
        { trial_onboarding_flow: true }
      else
        { skip_trial: true }
      end
    end
  end
end
