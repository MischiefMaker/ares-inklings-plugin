import { helper } from '@ember/component/helper';
import moment from 'moment';

export default helper(function localDate([date, format]) {
  if (!date) {
    return '';
  }

  if (!format) {
    format = 'MMM D, YYYY h:mm A';
  }

  return moment(date).format(format);
});
