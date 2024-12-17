require 'spec_helper'
require 'json'

describe 'oath' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context 'dont manage users file' do
          let(:params) do
            {
              'oath_users' => :undef,
              'oath' => true,
              'pam' => true,
            }
          end

          it { is_expected.to compile }
          it { is_expected.not_to contain_file('/etc/liboath/users.oath') }
        end
        context 'Should compile parameters exclude arrays defined' do
          let(:params) do
            {
              'oath' => true,
              'pam' => true,
              'oath_exclude_users' => ['root', 'simp'],
              'oath_exclude_groups' => ['root', 'simp'],
            }
          end

          it {
            is_expected.to compile
            is_expected.to contain_concat_fragment('oath_exclude_user_root').with_content(<<-EOM.gsub(%r{^\s+}, ''),
              root\n
            EOM
                                                                                         )
            is_expected.to contain_concat_fragment('oath_exclude_user_simp').with_content(<<-EOM.gsub(%r{^\s+}, ''),
              simp\n
            EOM
                                                                                         )
            is_expected.to contain_concat_fragment('oath_exclude_group_root').with_content(<<-EOM.gsub(%r{^\s+}, ''),
              root\n
            EOM
                                                                                          )
            is_expected.to contain_concat_fragment('oath_exclude_group_simp').with_content(<<-EOM.gsub(%r{^\s+}, ''),
              simp\n
            EOM
                                                                                          )
          }
        end

        good_pin  = ['"-"', '"+"', '1234', '12345678']
        good_user = ['root', 's1_mp-simP']
        good_type = ['HOTP', 'HOTP/T30', 'HOTP/T60', 'HOTP/T30/6', 'HOTP/T3022222/121212', 'HOTP/6']
        good_key  = ['1234', 'aasdf1234k']
        bad_pin   = ['a', '""']
        bad_type  = ['TOTP', 'HOTP/', 'HOTP/T', 'HOTP/T30/', '']
        bad_key   = ['12345']
        good_pin.each do |pin|
          good_user.each do |user|
            good_type.each do |token_type|
              good_key.each do |user_key|
                context "Should compile parameters #{token_type}\s#{user}\s#{pin}\s#{user_key}" do
                  let(:params) do
                    {
                      'oath' => true,
                      'pam' => true,
                      'oath_users' => JSON.parse(%({"#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}}))
                    }
                  end

                  it {
                    is_expected.to compile
                    test_pin = pin.delete('"')
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(%r{^\s+}, ''),
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}\n
                    EOM
                                                                                            )
                  }
                end
              end
            end
          end
        end
        good_user.first do |user|
          good_type.first do |token_type|
            good_key.first do |user_key|
              context "Should compile and use defaults #{token_type}\t#{user}\t1337\t#{user_key}" do
                let(:params) do
                  {
                    'oath'  => true,
                    'pam'   => true,
                    'oath_users' => JSON.parse(%({"defaults": { "pin": 1337 }, "#{user}": {"token_type": "#{token_type}", "secret_key": "#{user_key}"}}))
                  }
                end

                it { is_expected.to compile }
                it {
                  is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(%r{^\s+}, ''),
                    #{token_type}\t#{user}\t1337\t#{user_key}\n
                  EOM
                                                                                          )
                }
              end
            end
          end
        end
        good_pin.first do |pin|
          good_user.fisrt do |user|
            good_type.first do |token_type|
              good_key.first do |user_key|
                context "Should compile and override default values #{token_type}\t#{user}\t#{pin}\t#{user_key}" do
                  let(:params) do
                    {
                      'oath' => true,
                    'pam' => true,
                    'oath_users' => JSON.parse(%({"defaults": {"token_type": "HOTP", "pin": 1337 }, "#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}}))
                    }
                  end

                  it { is_expected.to compile }
                  it {
                    test_pin = pin.delete('"')
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(%r{^\s+}, ''),
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}
                    EOM
                                                                                            )
                  }
                end
              end
            end
          end
        end
        good_pin.first do |pin|
          good_user.first do |user|
            good_type.first do |token_type|
              good_key.first do |user_key|
                context 'Should compile parameters two users and a default' do
                  let(:params) do
                    {
                      'oath'  => true,
                      'pam'   => true,
                      'oath_users' => JSON.parse(%({"defaults": {"token_type": "HOTP"}, "#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}, "test_user": {"pin": 1212, "secret_key": "123412" }}))
                    }
                  end

                  it { is_expected.to compile }
                  it {
                    test_pin = pin.delete('"')
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(%r{^\s+}, ''),
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}
                    EOM
                                                                                            )
                    is_expected.to contain_concat_fragment('oath_user_test_user').with_content(<<-EOM.gsub(%r{^\s+}, ''),
                      HOTP\ttest_user\t1212\t123412
                    EOM
                                                                                              )
                  }
                end
              end
            end
          end
        end
        context 'Should not compile with bad type' do
          bad_type.each do |token_type|
            let(:params) do
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%({"root": {"token_type": "#{token_type}", "pin": 1234, "secret_key": "1212"}}))
              }
            end
            it { is_expected.not_to compile }
          end
        end
        context 'Should not compile with bad pin' do
          bad_pin.each do |pin|
            let(:params) do
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%({"root": {"token_type": "HOTP", "pin": #{pin}, "secret_key": "1234"}}))
              }
            end
            it { is_expected.not_to compile }
          end
        end
        context 'Should not compile with a bad key' do
          bad_key.each do |user_key|
            let(:params) do
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%({"root": {"token_type": "HOTP", "pin": 1234, "secret_key": "#{user_key}"}}))
              }
            end
            it { is_expected.not_to compile }
          end
        end
      end
    end
  end
end
