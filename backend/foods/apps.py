from django.apps import AppConfig
from django.db.models.signals import pre_migrate


class FoodsConfig(AppConfig):
    name = 'foods'
