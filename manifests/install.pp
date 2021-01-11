# This class is called from oath for installation of packages
# required to implement one-time passwords as part of PAM
# authentication.
#
# @api private
class oath::install {
  assert_private()

  package { 'liboath': ensure  => $::oath::package_ensure }
  package { 'pam_oath': ensure => $::oath::package_ensure }

}
