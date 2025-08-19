require 'spec_helper_acceptance'

test_name 'oath class'

describe 'oath class' do
  let(:manifest) do
    <<-EOS
      class { 'oath': }
    EOS
  end

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'works with no errors' do
      apply_manifest(manifest, catch_failures: true)
    end

    it 'is idempotent' do
      apply_manifest(manifest, catch_changes: true)
    end

    describe package('oathtool') do
      it { is_expected.to be_installed }
    end
  end
end
