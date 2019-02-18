require 'spec_helper'

describe 'oath' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('oath') }
    it { is_expected.to contain_class('oath') }
    it { is_expected.to contain_class('oath::oathtool_install') }
    it { is_expected.to contain_package('oathtool') }
  end

  shared_examples_for "an oath-enabled module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('oath') }
    it { is_expected.to contain_class('oath') }
    it { is_expected.to contain_class('oath::oathtool_install') }
    it { is_expected.to contain_package('oathtool') }
    it { is_expected.to contain_class('oath::install').that_comes_before('Class[oath::config]') }
    it { is_expected.to contain_class('oath::config') }
    it { is_expected.to contain_package('liboath') }
    it { is_expected.to contain_package('pam_oath') }
    it { is_expected.to contain_file('/etc/liboath').with({
      'ensure'  => 'directory',
      'owner'   => 'root',
      'group'   => 'root',
      'seluser' => 'system_u',
      'seltype' => 'var_auth_t',
    })}
    it { is_expected.to contain_file('/etc/liboath/exclude_users.oath').with({
      'ensure'  => 'file',
      'owner'   => 'root',
      'group'   => 'root',
      'mode'    => '0644',
      'seluser' => 'system_u',
      'seltype' => 'var_auth_t',
    })}
    it { is_expected.to contain_file('/etc/liboath/exclude_groups.oath').with({
      'ensure'  => 'file',
      'owner'   => 'root',
      'group'   => 'root',
      'mode'    => '0644',
      'seluser' => 'system_u',
      'seltype' => 'var_auth_t',
    })}
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context "oath class without any parameters" do
          let(:params) {{ }}
          it_behaves_like "a structured module"
        end

        context "oath class with oath enabled users undef" do
          let(:params) do
            {
            'oath' => true,
            'oath_users' => :undef,
            }
          end
          it_behaves_like "an oath-enabled module"
        end

        context "oath class with oath enabled users undef" do
          let(:params) do
            {
            'oath' => true
            }
          end
          it_behaves_like "an oath-enabled module"
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'oath class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :os => {
          :family => 'Solaris',
          :name   => 'Nexenta'
        }
      }}

      it { expect { is_expected.to contain_package('oath').to raise_error(/OS 'Nexenta' is not supported/) } }
    end
  end
end
