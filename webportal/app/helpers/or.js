// Shipped with this plugin rather than assuming ember-truth-helpers
// (or similar) is installed - {{or a b}} is not a core Ember helper.
import { helper } from '@ember/component/helper';

export default helper(function or(params) {
  return params.some(Boolean);
});
