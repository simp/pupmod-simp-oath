require 'spec_helper'
require 'json'

describe 'oath' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context "dont manage users file" do
          let(:params) do
            { 
              'oath_users' => :undef,
              'oath' => true,
              'pam' => true,
            }
          end
          it { is_expected.to compile }
          it { is_expected.to_not contain_file('/etc/liboath/users.oath')}
        end

        good_pin  = ['"-"','"+"','1234','12345678'] 
        good_user = ['root','s1_mp-simP']
        good_type = ['HOTP','HOTP/T30','HOTP/T60','HOTP/T30/6','HOTP/T3022222/121212','HOTP/6']
        good_key  = ['1234','aasdf1234k']
        bad_pin   = ['a','""']
        bad_user  = ['bad user','b&d_user','bad>user']
        bad_type  = ['TOTP','HOTP/','HOTP/T','HOTP/T30/','']
        bad_key   = ['12345']
        good_pin.each { |pin|
          good_user.each { |user|
            good_type.each { |token_type|
              good_key.each { |user_key|
                context "Should compile parameters #{token_type}\s#{user}\s#{pin}\s#{user_key}" do
                  let(:params) do 
                    {
                      'oath'  => true,
                      'pam' => true,
                      'oath_users' => JSON.parse(%Q[{"#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}}])
                    }
                  end
                  it { 
                    is_expected.to compile 
                    test_pin = pin.gsub("\"", "")
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(/^\s+/,'')
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}\n
                    EOM
                    )
                  }
                end
              }
            }
          }
        }
        good_user.first { |user|
          good_type.first { |token_type|
            good_key.first { |user_key|
              context "Should compile and use defaults #{token_type}\t#{user}\t1337\t#{user_key}" do
                let(:params) do 
                  {
                    'oath'  => true,
                    'pam'   => true,
                    'oath_users' => JSON.parse(%Q[{"defaults": { "pin": 1337 }, "#{user}": {"token_type": "#{token_type}", "secret_key": "#{user_key}"}}])
                  }
                end
                it { is_expected.to compile }
                it {
                is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(/^\s+/,'')
                    #{token_type}\t#{user}\t1337\t#{user_key}\n
                  EOM
                  )
                }
              end
            }
          }
        }
        good_pin.first { |pin|
          good_user.fisrt { |user|
            good_type.first { |token_type|
              good_key.first { |user_key|
                context "Should compile and override default values #{token_type}\t#{user}\t#{pin}\t#{user_key}" do
                  let(:params) do {
                    'oath'  => true,
                    'pam'   => true,
                    'oath_users' => JSON.parse(%Q[{"defaults": {"token_type": "HOTP", "pin": 1337 }, "#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}}])
                  } end
                  it { is_expected.to compile }
                  it {
                    test_pin = pin.gsub("\"", "")
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(/^\s+/,'')
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}
                    EOM
                    )
                  }
                end
              }
            }
          }
        }
        good_pin.first { |pin|
          good_user.first { |user|
            good_type.first { |token_type|
              good_key.first { |user_key|
                context "Should compile parameters two users and a default" do
                  let(:params) do 
                    {
                      'oath'  => true,
                      'pam'   => true,
                      'oath_users' => JSON.parse(%Q[{"defaults": {"token_type": "HOTP"}, "#{user}": {"token_type": "#{token_type}", "pin": #{pin}, "secret_key": "#{user_key}"}, "test_user": {"pin": 1212, "secret_key": "123412" }}])
                    }
                  end
                  it { is_expected.to compile }
                  it { 
                    test_pin = pin.gsub("\"", "")
                    is_expected.to contain_concat_fragment("oath_user_#{user}").with_content(<<-EOM.gsub(/^\s+/,'')
                      #{token_type}\t#{user}\t#{test_pin}\t#{user_key}
                    EOM
                    )
                    is_expected.to contain_concat_fragment("oath_user_test_user").with_content(<<-EOM.gsub(/^\s+/,'')
                      HOTP\ttest_user\t1212\t123412
                    EOM
                    )
                  }
                end
              }
            }
          }
        }
        context "Should not compile with bad users" do
          bad_user.each { |user|
            let(:params) do 
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%Q[{"#{user}": {"token_type": "HOTP", "pin": 1234, "secret_key": "1212"}}])
              }
            end
            it { is_expected.to_not compile }
          }
        end
        context "Should not compile with bad type" do
          bad_type.each { |token_type|
            let(:params) do 
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%Q[{"root": {"token_type": "#{token_type}", "pin": 1234, "secret_key": "1212"}}])
              }
            end
            it { is_expected.to_not compile }
          }
        end
        context "Should not compile with bad pin" do
          bad_pin.each { |pin|
            let(:params) do 
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%Q[{"root": {"token_type": "HOTP", "pin": #{pin}, "secret_key": "1234"}}])
              }
            end
            it { is_expected.to_not compile }
          }
        end
        context "Should not compile with a bad key" do
          bad_key.each { |user_key|
            let(:params) do 
              {
                'oath'  => true,
                'pam'   => true,
                'oath_users' => JSON.parse(%Q[{"root": {"token_type": "HOTP", "pin": 1234, "secret_key": "#{user_key}"}}])
              }
            end
            it { is_expected.to_not compile }
          }
        end
      end
    end
  end
end
