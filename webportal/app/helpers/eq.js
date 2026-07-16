// Shipped with this plugin rather than assuming ember-truth-helpers
// (or similar) is installed - {{eq a b}} is not a core Ember helper.
import { helper } from '@ember/component/helper';

export default helper(function eq([a, b]) {
  return a === b;
});
