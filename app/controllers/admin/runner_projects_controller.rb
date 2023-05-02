# frozen_string_literal: true

class Admin::RunnerProjectsController < Admin::ApplicationController
  before_action :project, only: [:create]

  feature_category :runner
  urgency :low

  def create
    @runner = Ci::Runner.find(params[:runner_project][:runner_id])

    if ::Ci::Runners::AssignRunnerService.new(@runner, @project, current_user).execute.success?
      flash[:success] = s_('Runners|Runner assigned to project.')
      redirect_to edit_admin_runner_url(@runner)
    else
      redirect_to edit_admin_runner_url(@runner), alert: s_('Runners|Failed adding runner to project')
    end
  end

  def destroy
    rp = Ci::RunnerProject.find(params[:id])
    runner = rp.runner

    ::Ci::Runners::UnassignRunnerService.new(rp, current_user).execute

    flash[:success] = s_('Runners|Runner unassigned from project.')
    redirect_to edit_admin_runner_url(runner), status: :found
  end

  private

  def project
    @project = Project.find_by_full_path(
      [params[:namespace_id], '/', params[:project_id]].join('')
    )
    @project || render_404
  end
end
