from django.utils.functional import cached_property
from django.core.paginator import Paginator
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response



# class FasterDjangoPaginator(Paginator):
#     @cached_property
#     def count(self):
#         # only select 'id' for counting, much cheaper
#         print(self.object_list._result_cache)
#         return self.object_list.count()




class CustomPagination(PageNumberPagination):

    # django_paginator_class = FasterDjangoPaginator

    def get_paginated_response(self, data):
        return Response({
            "pagination": {
                "next": self.get_next_link(),
                "previous": self.get_previous_link(),
                "total_results": self.page.paginator.count,
                "current_page": self.page.number,
                "total_pages": self.page.paginator.num_pages,
            },
            "results": data,
        })


class LargeResultsSetPagination(CustomPagination):
    page_size = 1000
    page_size_query_param = "page_size"
    max_page_size = 10000


class StandardResultsSetPagination(CustomPagination):
    page_size = 100
    page_size_query_param = "page_size"
    max_page_size = 1000
