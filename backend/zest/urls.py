from django.contrib import admin
from rest_framework import permissions
from django.urls import path, include, re_path
from django.conf.urls.i18n import i18n_patterns
from django.conf.urls.static import static

# from drf_yasg2.views import get_schema_view
# from drf_yasg2 import openapi
from drf_spectacular.views import (
    SpectacularJSONAPIView,
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from django.conf import settings

from .api import InfoView

# schema_view = get_schema_view(
#     openapi.Info(
#         title=settings.API_TITLE,
#         default_version="v0.0.1",
#         description=settings.API_DESC,
#         #   terms_of_service="",
#         #   contact=openapi.Contact(email="contact@snippets.local"),
#         #   license=openapi.License(name="BSD License"),
#     ),
#     public=True,
#     permission_classes=(permissions.AllowAny,),
# )

normal_urls = i18n_patterns(
    path("admin/", admin.site.urls), prefix_default_language=False
)

api_urls = [
    path("api/v1/auth/", include("dj_rest_auth.urls")),
    path("api/v1/auth/registration/", include("dj_rest_auth.registration.urls")),
    path("api/v1/", include("users.urls")),
    path("api/v1/", include("units.urls")),
    path("api/v1/", include("foods.urls")),
    path("api/v1/", include("tags.urls")),
    path("api/v1/", include("recipes.api.urls")),
    path("api/v1/", include("shopping_lists.urls")),
    path("api/v1/", include("favorites.urls")),
    path("api/v1/info", InfoView.as_view()),
    # path("swag", SpectacularJSONAPIView.as_view()),
    # YOUR PATTERNS
    path("api/v1/schema/", SpectacularJSONAPIView.as_view(), name="schema"),
    # Optional UI:
    path(
        "api/v1/schema/swagger-ui/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    path(
        "api/v1/schema/redoc/",
        SpectacularRedocView.as_view(url_name="schema"),
        name="redoc",
    ),
    # path('silk/', include('silk.urls', namespace='silk'))
]

# api_docs_urls = [
#     re_path(
#         r"^swagger(?P<format>\.json|\.yaml)$",
#         schema_view.without_ui(cache_timeout=0),
#         name="schema-json",
#     ),
#     re_path(
#         r"^swagger/$",
#         schema_view.with_ui("swagger", cache_timeout=0),
#         name="schema-swagger-ui",
#     ),
#     re_path(r"^redoc/$", schema_view.with_ui("redoc", cache_timeout=0), name="schema-redoc"),
# ]

urlpatterns = api_urls
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
# if (prefix := getattr(settings, "API_PREFIX")):
#     urlpatterns = [path(fr'^{prefix}/', include(urlpatterns))]
urlpatterns += normal_urls
