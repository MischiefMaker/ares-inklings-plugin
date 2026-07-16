// Same as join-list, but uppercased - used for the "PRIVATE TO X"
// badge text. Not a core Ember helper, so shipped with this plugin.
import { helper } from '@ember/component/helper';

export default helper(function joinListUpper([list]) {
  return (list || []).join(', ').toUpperCase();
});
