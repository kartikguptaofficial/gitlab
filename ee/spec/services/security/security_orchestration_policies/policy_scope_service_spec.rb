# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyScopeService, feature_category: :security_policy_management do
  let_it_be_with_refind(:namespace_settings) do
    create(:namespace_settings, toggle_security_policies_policy_scope: true)
  end

  let_it_be_with_refind(:group) { create(:group, namespace_settings: namespace_settings) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }

  let(:service) { described_class.new(project: project) }

  shared_examples 'when toggle_security_policies_policy_scope is disabled for group' do
    before do
      namespace_settings.update!(toggle_security_policies_policy_scope: false)
    end

    it { is_expected.to eq true }
  end

  describe '#policy_applicable?' do
    let(:policy) { nil }

    subject(:policy_applicable) { service.policy_applicable?(policy) }

    context 'when security_policies_policy_scope feature is disabled' do
      before do
        stub_feature_flags(security_policies_policy_scope: false)
      end

      it { is_expected.to eq true }
    end

    context 'when security_policies_policy_scope feature is enabled' do
      context 'when policy is empty' do
        let(:policy) { {} }

        it { is_expected.to eq false }

        it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
      end

      context 'when policy is not empty' do
        context 'when policy scope is not set for compliance framework nor project' do
          let(:policy) { { enabled: true } }

          it { is_expected.to eq true }
        end

        context 'when policy is scoped for compliance framework' do
          let(:policy) do
            {
              policy_scope: {
                compliance_frameworks: [{ id: compliance_framework.id }]
              }
            }
          end

          context 'when project does not have compliance framework set' do
            it { is_expected.to eq false }

            it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'

            context 'when policy additionally includes the project in policy' do
              let(:policy) do
                {
                  policy_scope: {
                    compliance_frameworks: [{ id: compliance_framework.id }],
                    projects: {
                      including: [{ id: project.id }]
                    }
                  }
                }
              end

              it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
            end
          end

          context 'when project have compliance framework set' do
            let_it_be(:compliance_framework_project_setting) do
              create(:compliance_framework_project_setting,
                project: project,
                compliance_management_framework: compliance_framework)
            end

            it { is_expected.to eq true }

            context 'when policy additionally excludes the project from policy' do
              let(:policy) do
                {
                  policy_scope: {
                    compliance_frameworks: [{ id: compliance_framework.id }],
                    projects: {
                      excluding: [{ id: project.id }]
                    }
                  }
                }
              end

              it { is_expected.to eq false }

              it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
            end

            context 'when non-existing compliance framework is set' do
              let(:policy) do
                {
                  policy_scope: {
                    compliance_frameworks: [{ id: non_existing_record_id }]
                  }
                }
              end

              it { is_expected.to eq false }

              it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
            end
          end
        end

        context 'when policy is scoped for projects' do
          context 'with including project scope' do
            context 'when included project scope is not matching project id' do
              let(:policy) do
                {
                  policy_scope: {
                    projects: {
                      including: [{ id: non_existing_record_id }]
                    }
                  }
                }
              end

              it { is_expected.to eq false }

              it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
            end

            context 'when included project scope is matching project id' do
              let(:policy) do
                {
                  policy_scope: {
                    projects: {
                      including: [{ id: project.id }]
                    }
                  }
                }
              end

              it { is_expected.to eq true }

              context 'when additionally excluding project scope is matching project id' do
                let(:policy) do
                  {
                    policy_scope: {
                      projects: {
                        including: [{ id: project.id }],
                        excluding: [{ id: project.id }]
                      }
                    }
                  }
                end

                it { is_expected.to eq false }

                it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
              end
            end
          end

          context 'with excluding project scope' do
            context 'when excluding project scope is not matching project id' do
              let(:policy) do
                {
                  policy_scope: {
                    projects: {
                      excluding: [{ id: non_existing_record_id }]
                    }
                  }
                }
              end

              it { is_expected.to eq true }
            end

            context 'when excluding project scope is matching project id' do
              let(:policy) do
                {
                  policy_scope: {
                    projects: {
                      excluding: [{ id: project.id }]
                    }
                  }
                }
              end

              it { is_expected.to eq false }

              it_behaves_like 'when toggle_security_policies_policy_scope is disabled for group'
            end
          end
        end
      end
    end
  end
end
