import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';

export default class InklingSearchComponent extends Component {
  @service gameApi;
  @tracked query = '';
  @tracked searching = false;
  @tracked showResults = false;
  @tracked results = [];
  @tracked page = 1;
  @tracked totalPages = 0;
  @tracked totalCount = 0;

  @action
  async performSearch(e) {
    e?.preventDefault();
    if (!this.query?.trim()) {
      this.results = [];
      this.showResults = false;
      return;
    }

    this.searching = true;
    try {
      const response = await this.gameApi.requestOne('inklings_search', {
        query: this.query,
        page: this.page || 1
      }, 'home');

      if (!response.error) {
        this.results = response.inklings || [];
        this.page = response.page || 1;
        this.totalPages = response.total_pages || 0;
        this.totalCount = response.total_count || 0;
        this.showResults = true;
      }
    } finally {
      this.searching = false;
    }
  }

  @action
  clearSearch() {
    this.query = '';
    this.results = [];
    this.showResults = false;
    this.page = 1;
  }

  @action
  openResult(inkling) {
    if (this.args.onSelect) {
      this.args.onSelect(inkling);
    }
  }

  @action
  nextPage() {
    if (this.page < this.totalPages) {
      this.page = this.page + 1;
      this.performSearch();
    }
  }

  @action
  previousPage() {
    if (this.page > 1) {
      this.page = this.page - 1;
      this.performSearch();
    }
  }
}
