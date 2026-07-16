// Shipped with this plugin rather than assuming ember-truth-helpers
// (or similar) is installed - {{not a}} is not a core Ember helper.
import { helper } from '@ember/component/helper';

export default helper(function not([value]) {
  return !value;
});
