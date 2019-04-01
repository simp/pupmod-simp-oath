# This class is called from oath for installation of packages
# required to implement one-time passwords as part of PAM
# authentication.
#
# @api private
class oath::install {
  assert_private()

  package { 'liboath': ensure  => $::oath::package_ensure }
  package { 'pam_oath': ensure => $::oath::package_ensure }

  if $facts['os']['release']['major'] == '6' {
    file { '/lib64/security/pam_oath.so':
      ensure => 'link',
      target => '/usr/lib64/security/pam_oath.so',
    }
  }
}
