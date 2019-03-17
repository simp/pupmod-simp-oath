# This module is utilized by other modules in SIMP to download TOTP required
# packages and configure them with sane defaults as to make pam_oath.so a
# functional pam module if used.
#
# @param oath
#   Whether or not to install pam_oath and liboath (if true) or just oathtool
#   (a command-line utility for getting a 2FA code from a corresponding secret
#   key.
#
#   * Defaults to the global catalyst `simp_options::oath`.
#
# @param pam
#   Whether or not pam is configured on the simp system.
#
#   * Will not install pam_oath without `$pam` being `true`.
#
#   **WARNING** If this is overriden to true, pam will install as a dependency
#   of pam_oath
#
# @param package_ensure
#   Sets the value for resource => package, key => ensure.
#
# @param oath_exclude_users
#   Optional array that will enter each array member as a user in the 
#   exclude_users.oath file, keeping them from needing oath 2FA when configured
#   for other users. 
#
# @param oath_exclude_groups
#   Optional array that will enter each array member as a group in the 
#   exclude_groups.oath file, keeping members of these groups from needing 
#   oath 2FA when configured for other users. 
#
# @param oath_users
#   `Hash` of users processed to create the users.oath file required by the
#   pam_oath.so module.
#
#   Defaults to hieradata in data/common.yaml. If this is deleted, or set to
#   undef, puppet will not manage users.oath. Processing happens in
#   manifests/config.pp with the config define being in
#   manifests/config/user.pp
#
# Example hieradata
#
#   oath::oath_users:
#     defaults:
#       token_type: 'HOTP/T30/6'
#       pin: '-'
#     user:
#       secret_key: 'my_secret_key'
#     other_user:
#       pin: '1234' # fields in user with override defaults
#       secret_key: 'secret_key_for_other_user'
#
# @author https://github.com/simp/pupmod-simp-oath/graphs/contributors
#
class oath (
  Boolean                $oath           = simplib::lookup('simp_options::oath', { 'default_value' => false }),
  Boolean                $pam            = simplib::lookup('simp_options::pam', { 'default_value' => true }),
  Simplib::PackageEnsure $package_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'present'}),
  Optional[Hash]         $oath_users     = undef,
  Optional[Array]        $oath_exclude_users = undef,
  Optional[Array]        $oath_exclude_groups = undef
) {
  include '::oath::oathtool_install'

  if ($pam and $oath){
    simplib::assert_metadata($module_name)

    include '::oath::install'
    include '::oath::config'

    Class[ '::oath::install' ]
    -> Class[ '::oath::config' ]
  }
}
