import sys
import os
sys.path.append(os.getcwd())

from app.schemas.profile import HouseholdType, ProfileCreate
from pydantic import ValidationError

print(f"Enum members: {list(HouseholdType)}")

try:
    p = ProfileCreate(
        householdType="concubine",
        goal="house"
    )
    print("Validation SUCCESS")
except ValidationError as e:
    print(f"Validation FAILED: {e}")
except Exception as e:
    print(f"Error: {e}")
