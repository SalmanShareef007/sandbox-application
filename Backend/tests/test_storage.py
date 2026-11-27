from concurrent.futures import ThreadPoolExecutor

import pytest

from app.services.storage_service import JSONStorageService as Storage


def test_transaction_rolls_back_all_collections(database):
    with pytest.raises(RuntimeError):
        with Storage.lock():
            Storage.write("requests.json", [{"value": 1}])
            Storage.write("approvals.json", [{"value": 2}])
            raise RuntimeError("interrupted")
    assert Storage.read("requests.json") == []
    assert Storage.read("approvals.json") == []


def test_concurrent_updates_do_not_lose_records(database):
    def append(value):
        with Storage.lock():
            documents = Storage.read("requests.json")
            documents.append({"value": value})
            Storage.write("requests.json", documents)

    with ThreadPoolExecutor(max_workers=8) as executor:
        list(executor.map(append, range(30)))
    assert sorted(item["value"] for item in Storage.read("requests.json")) == list(range(30))


def test_invalid_collection_is_rejected(database):
    with pytest.raises(ValueError):
        Storage.read("../secrets.json")
