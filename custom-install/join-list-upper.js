// Joins an array of strings and uppercases the result (for "PRIVATE TO X" badge text).
// (AresMUSH doesn't include ember-composable-helpers or ember-cli-string-helpers, so this is shipped with the plugin.)
import { helper } from '@ember/component/helper';

export default helper(function joinListUpper([list]) {
  return (list || []).join(', ').toUpperCase();
});
