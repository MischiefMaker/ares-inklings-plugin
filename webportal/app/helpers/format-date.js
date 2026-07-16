// Formats an ISO timestamp string (as returned by inklings_api.rb)
// for display. Not a core Ember helper, so shipped with this plugin.
import { helper } from '@ember/component/helper';

export default helper(function formatDate([value]) {
  if (!value) {
    return '';
  }
  let date = new Date(value);
  if (isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
});
