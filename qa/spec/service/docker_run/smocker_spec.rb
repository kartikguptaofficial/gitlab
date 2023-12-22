# frozen_string_literal: true

module QA
  RSpec.describe Service::DockerRun::Smocker do
    let(:name) { 'smocker-12345' }
    let(:network) { 'thenet' }
    let(:host_ip) { '1.2.3.4' }

    subject(:smocker_container) { described_class.new(name: name) }

    before do
      # rubocop:disable RSpec/AnyInstanceOf -- allow_next_instance_of relies on gitlab/rspec
      allow_any_instance_of(described_class).to receive(:network).and_return(network)
      # rubocop:enable RSpec/AnyInstanceOf

      allow(smocker_container).to receive(:host_ip).and_return(host_ip)
    end

    describe '#host_name' do
      shared_examples 'returns host ip' do
        it 'returns host ip' do
          expect(smocker_container.host_name).to eq(host_ip)
        end
      end

      shared_examples 'returns name.network' do
        it 'returns name.network' do
          expect(smocker_container.host_name).to eq("#{name}.#{network}")
        end
      end

      context 'when running in CI' do
        before do
          allow(Runtime::Env).to receive(:running_in_ci?).and_return(true)
        end

        context 'when network is not bridge' do
          it_behaves_like 'returns name.network'
        end

        context 'when network is bridge' do
          let(:network) { 'bridge' }

          it_behaves_like 'returns host ip'
        end
      end

      context 'when running not in CI' do
        before do
          allow(Runtime::Env).to receive(:running_in_ci?).and_return(false)
        end

        context 'when QA hostname is not set' do
          it_behaves_like 'returns host ip'
        end

        context 'when QA hostname is set' do
          before do
            allow(Runtime::Env).to receive(:qa_hostname).and_return('qa-hostname')
          end

          it_behaves_like 'returns name.network'
        end
      end
    end
  end
end
