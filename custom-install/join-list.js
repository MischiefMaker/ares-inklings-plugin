// Joins an array of strings for display, e.g. "Bob, Alice".
// (AresMUSH doesn't include ember-composable-helpers, so this is shipped with the plugin.)
import { helper } from '@ember/component/helper';

export default helper(function joinList([list]) {
  return (list || []).join(', ');
});
