// Joins an array of names for display, e.g. "Bob, Alice". Not a core
// Ember helper, so shipped with this plugin.
import { helper } from '@ember/component/helper';

export default helper(function joinList([list]) {
  return (list || []).join(', ');
});
