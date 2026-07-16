// Shipped with this plugin rather than assuming ember-truth-helpers
// (or similar) is installed - {{and a b}} is not a core Ember helper.
import { helper } from '@ember/component/helper';

export default helper(function and(params) {
  return params.every(Boolean);
});
