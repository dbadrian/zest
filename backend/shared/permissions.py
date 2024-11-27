from rest_framework.permissions import BasePermission, IsAdminUser, SAFE_METHODS


class IsAdminOrOwnerOrReadOnly(BasePermission):

    def has_object_permission(self, request, view, obj):
        # Read-only permissions are allowed for any request
        if request.method in SAFE_METHODS:
            return True
        # Write permissions are only allowed to the author of a post OR any admin user
        is_admin = super().has_permission(request, view)
        return obj.owner == request.user or is_admin


class IsOwnerOrReadOnly(BasePermission):

    def has_object_permission(self, request, view, obj):
        # Read-only permissions are allowed for any request
        if request.method in SAFE_METHODS:
            return True
        # Write permissions are only allowed to the author of a post
        return obj.owner == request.user


class IsAdminOrReadOnly(IsAdminUser):

    def has_permission(self, request, view):
        is_admin = super().has_permission(request, view)
        return request.method in SAFE_METHODS or is_admin

class IsAdminOrCreateOnly(IsAdminUser):

    def has_permission(self, request, view):
        is_admin = super().has_permission(request, view)
        return request.method in list(SAFE_METHODS) + ["POST", "PUT"] or is_admin
